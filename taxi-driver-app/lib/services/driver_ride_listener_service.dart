import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxiapp/api/driver_api.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/services/driver_location_service.dart';
import 'package:taxiapp/services/driver_socket_service.dart';
import 'package:taxiapp/utils/jwt_utils.dart';
import 'package:taxiapp/utils/navigation_logger.dart';
import 'package:taxiapp/utils/ride_navigation_utils.dart';

/// Keeps driver ONLINE, socket connected, and polls incoming rides.
class DriverRideListenerService {
  DriverRideListenerService._();
  static final DriverRideListenerService instance = DriverRideListenerService._();

  static const double nearbyDispatchKm = 10.0;

  final DriverSocketService _socket = DriverSocketService();
  final DriverLocationService _location = DriverLocationService.instance;
  final StreamController<Map<String, dynamic>> _incomingController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get incomingRideStream => _incomingController.stream;
  Stream<Map<String, dynamic>> get rideCancelledStream => _cancelController.stream;

  final StreamController<Map<String, dynamic>> _cancelController =
      StreamController<Map<String, dynamic>>.broadcast();

  final Set<String> _announcedRideIds = <String>{};
  Timer? _pollTimer;
  StreamSubscription<DriverGpsFix>? _gpsSub;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamSubscription<Map<String, dynamic>>? _cancelSub;
  bool _running = false;
  double? _driverLat;
  double? _driverLng;
  String? lastError;

  bool get isRunning => _running;

  Future<({double latitude, double longitude})?> currentPosition() async {
    if (_driverLat != null && _driverLng != null) {
      return (latitude: _driverLat!, longitude: _driverLng!);
    }
    final fix = await _location.getFastFix();
    if (fix == null) return null;
    return (latitude: fix.latitude, longitude: fix.longitude);
  }

  /// Returns immediately when cached GPS / web fallback is available; syncs API in background.
  Future<bool> start() async {
    if (_running) return true;

    final auth = AuthService();
    final token = auth.token;
    if (token == null) {
      lastError = 'Not logged in.';
      return false;
    }

    var driverId = auth.driverId ?? userIdFromJwt(token) ?? '';
    if (driverId.isEmpty) {
      await _resolveDriverId(auth, token);
      driverId = auth.driverId ?? userIdFromJwt(token) ?? '';
    }
    if (driverId.isEmpty) {
      lastError = 'Driver profile loading… try again in a moment.';
      return false;
    }

    final cached = _location.latest;
    if (cached != null) {
      _driverLat = cached.latitude;
      _driverLng = cached.longitude;
    } else if (kIsWeb) {
      _driverLat = 12.9700;
      _driverLng = 80.2500;
    }

    if (_driverLat == null || _driverLng == null) {
      if (!await _location.ensurePermission()) {
        lastError = 'Location permission required to go online.';
        NavigationLogger.error('online', lastError!);
        return false;
      }
    }

    unawaited(_location.startTracking());

    if (_driverLat == null || _driverLng == null) {
      final fix = await _location.getFastFix().timeout(
        const Duration(milliseconds: 600),
        onTimeout: () => _location.latest,
      );
      if (fix != null) {
        _driverLat = fix.latitude;
        _driverLng = fix.longitude;
      } else if (kIsWeb) {
        _driverLat = 12.9700;
        _driverLng = 80.2500;
      } else {
        lastError = 'GPS unavailable. Enable location services.';
        NavigationLogger.error('online', lastError!);
        return false;
      }
    }

    final onlineOk = await _syncOnline(auth, token, driverId, _driverLat!, _driverLng!);
    if (!onlineOk) {
      _teardownListeners();
      return false;
    }

    _attachListeners(driverId);

    _running = true;
    lastError = null;

    unawaited(_refineGpsPosition());
    return true;
  }

  void _teardownListeners() {
    _pollTimer?.cancel();
    _gpsSub?.cancel();
    _socketSub?.cancel();
    _cancelSub?.cancel();
    _pollTimer = null;
    _gpsSub = null;
    _socketSub = null;
    _cancelSub = null;
    _socket.disconnect();
  }

  Future<void> _refineGpsPosition() async {
    final fix = await _location.getFastFix();
    if (fix == null || !_running) return;
    _driverLat = fix.latitude;
    _driverLng = fix.longitude;
    _socket.updateLocation(lat: fix.latitude, lng: fix.longitude);
  }

  Future<void> _resolveDriverId(AuthService auth, String token) async {
    final profile = await DriverApi.withToken(token).getDriverProfile();
    final id = (profile?['id'] ??
            profile?['_id'] ??
            profile?['data']?['_id'] ??
            profile?['data']?['id'] ??
            profile?['driver']?['_id'] ??
            profile?['driver']?['id'] ??
            '')
        .toString();
    if (id.isNotEmpty) auth.driverId = id;
  }

  void _attachListeners(String driverId) {
    _socketSub?.cancel();
    _cancelSub?.cancel();
    _socketSub = _socket.rideNewStream.listen(_emitIfNew);
    _cancelSub = _socket.rideCancelledStream.listen(_onRideCancelledEvent);
    _socket.rideUpdateStream.listen((payload) {
      final status = (payload['status'] ?? '').toString().toUpperCase();
      final rideId = (payload['ride_id'] ?? payload['rideId'] ?? '').toString();
      if (status == 'CANCELLED' && rideId.isNotEmpty) {
        _announcedRideIds.remove(rideId);
      }
    });

    _gpsSub?.cancel();
    _gpsSub = _location.fixes.listen((gpsFix) {
      _driverLat = gpsFix.latitude;
      _driverLng = gpsFix.longitude;
      _socket.updateLocation(lat: gpsFix.latitude, lng: gpsFix.longitude);
    });

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollIncoming());
    unawaited(_pollIncoming());
  }

  Duration get _pollInterval =>
      _socket.isConnected ? const Duration(seconds: 10) : const Duration(seconds: 4);

  Future<bool> _syncOnline(
    AuthService auth,
    String token,
    String driverId,
    double lat,
    double lng,
  ) async {
    final statusOk = await auth.setDriverStatus('ONLINE');
    if (!statusOk) {
      final backendMessage = auth.lastDriverStatusError ?? '';
      if (backendMessage.toLowerCase().contains('not verified')) {
        lastError =
            'Admin approval pending. Upload documents and wait for admin to approve your account.';
      } else if (backendMessage.toLowerCase().contains('profile incomplete')) {
        lastError =
            'Complete your driver profile and vehicle details before going online.';
      } else {
        lastError = backendMessage.isNotEmpty
            ? backendMessage
            : 'Could not go online. Check verification and profile.';
      }
      return false;
    }

    await _socket.connect(token: token, driverId: driverId, lat: lat, lng: lng);
    if (auth.driverId == null || auth.driverId!.isEmpty) {
      await _resolveDriverId(auth, token);
    }
    return true;
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _pollTimer?.cancel();
    _gpsSub?.cancel();
    _socketSub?.cancel();
    _cancelSub?.cancel();
    _pollTimer = null;
    _gpsSub = null;
    _socketSub = null;
    _cancelSub = null;
    unawaited(AuthService().setDriverStatus('OFFLINE'));
    _socket.disconnect();
    unawaited(_location.stopTracking());
  }

  void clearAnnounced(String rideId) => _announcedRideIds.remove(rideId);

  Future<void> _pollIncoming() async {
    final token = AuthService().token;
    if (token == null) return;
    final result = await DriverApi.withToken(token).fetchIncomingRides(
      lat: _driverLat,
      lng: _driverLng,
    );
    if (result.errorMessage != null) {
      lastError = result.errorMessage;
    } else {
      lastError = null;
    }
    for (final ride in result.rides) {
      final status = (ride['status']?.toString() ?? '').toUpperCase();
      if (status == 'SEARCHING_DRIVER' || status == 'REQUESTED' || status == 'requested') {
        _emitIfNew(_normalizeApiRide(ride));
      }
    }
  }

  void _onRideCancelledEvent(Map<String, dynamic> payload) {
    final rideId = (payload['ride_id'] ?? payload['rideId'] ?? payload['id'] ?? '').toString();
    if (rideId.isNotEmpty) {
      _announcedRideIds.remove(rideId);
    }
    _cancelController.add(payload);
  }

  void _emitIfNew(Map<String, dynamic> raw) {
    final ride = raw.containsKey('pickup') && raw['pickup'] is String
        ? raw
        : _normalizeSocketRide(raw);
    final id = (ride['id'] ?? raw['ride_id'] ?? raw['rideId'] ?? raw['id'] ?? '').toString();
    if (id.isEmpty || _announcedRideIds.contains(id)) return;
    ride['id'] = id;

    final maxKm = (raw['nearby_km'] as num?)?.toDouble() ?? nearbyDispatchKm;

    num? nearKm = ride['nearPickupKm'] as num?;
    nearKm ??= ride['distance_to_pickup_km'] as num?;
    if (nearKm == null && raw['distance_to_pickup_km'] is num) {
      nearKm = raw['distance_to_pickup_km'] as num;
    }
    if (nearKm == null && raw['distance_to_pickup_m'] is num) {
      nearKm = (raw['distance_to_pickup_m'] as num) / 1000;
    }
    if (nearKm == null && raw['distance_m'] is num) {
      nearKm = (raw['distance_m'] as num) / 1000;
    }
    nearKm ??= _distanceKm(ride);

    if (_driverLat != null && _driverLng != null) {
      if (nearKm == null || nearKm > maxKm) return;
    }

    if (nearKm != null) ride['nearPickupKm'] = nearKm;
    _announcedRideIds.add(id);
    _incomingController.add(ride);
  }

  double? _distanceKm(Map<String, dynamic> ride) {
    if (_driverLat == null || _driverLng == null) return null;
    final pickup = RideNavigationUtils.pickupFromRide(ride);
    if (pickup == null) return null;
    final meters = Geolocator.distanceBetween(
      _driverLat!,
      _driverLng!,
      pickup.latitude,
      pickup.longitude,
    );
    return meters / 1000;
  }

  Map<String, dynamic> _normalizeApiRide(Map<String, dynamic> ride) {
    final pickup = ride['pickup'];
    final drop = ride['drop'];
    final pickupLl = RideNavigationUtils.pickupFromRide(ride);
    final dropLl = RideNavigationUtils.dropFromRide(ride);
    final tripKm = _tripDistanceKm(ride, pickupLl, dropLl);
    final paymentMode = (ride['payment_mode'] ?? ride['paymentMode'] ?? 'CASH').toString();
    final customerMap = ride['customer'] is Map ? ride['customer'] as Map : null;
    final ui = <String, dynamic>{
      'id': (ride['id'] ?? ride['_id'] ?? ride['ride_id']).toString(),
      'passengerName': ride['customer_name'] ??
          ride['passengerName'] ??
          customerMap?['name'] ??
          'Passenger',
      'customer_phone': ride['customer_phone'] ??
          ride['customerPhone'] ??
          customerMap?['phone'],
      'customer': customerMap,
      'pickup': _fmtLocation(pickup, fallback: ride['pickupAddress']?.toString()),
      'dropoff': _fmtLocation(drop, fallback: ride['dropAddress']?.toString()),
      'distance': tripKm.toStringAsFixed(1),
      'tripDistanceKm': tripKm,
      'duration': ride['duration_min']?.toString() ?? '${(tripKm * 2).round()}',
      'fare': (ride['fare'] as num?)?.toDouble() ?? 0.0,
      'paymentMode': paymentMode,
      'status': (ride['status'] ?? 'SEARCHING_DRIVER').toString(),
      if (pickupLl != null) ...{
        'pickupLat': pickupLl.latitude,
        'pickupLng': pickupLl.longitude,
        'pickup': pickup is Map ? pickup : {'lat': pickupLl.latitude, 'lng': pickupLl.longitude},
      },
      if (dropLl != null) ...{
        'dropLat': dropLl.latitude,
        'dropLng': dropLl.longitude,
        'drop': drop is Map ? drop : {'lat': dropLl.latitude, 'lng': dropLl.longitude},
      },
    };
    ui['nearPickupKm'] = ride['distance_to_pickup_km'] is num
        ? (ride['distance_to_pickup_km'] as num)
        : ride['distance_m'] is num
            ? (ride['distance_m'] as num) / 1000
            : _distanceKm(ui);
    return ui;
  }

  Map<String, dynamic> _normalizeSocketRide(Map<String, dynamic> ride) {
    final pickupLl = RideNavigationUtils.pickupFromRide(ride);
    final dropLl = RideNavigationUtils.dropFromRide(ride);
    final tripKm = _tripDistanceKm(ride, pickupLl, dropLl);
    final paymentMode = (ride['payment_mode'] ?? ride['paymentMode'] ?? 'CASH').toString();
    final customerMap = ride['customer'] is Map ? ride['customer'] as Map : null;
    final ui = <String, dynamic>{
      'id': (ride['rideId'] ?? ride['ride_id'] ?? ride['id']).toString(),
      'passengerName': ride['customerName'] ??
          ride['customer_name'] ??
          customerMap?['name'] ??
          'Passenger',
      'customer_phone': ride['customer_phone'] ??
          ride['customerPhone'] ??
          customerMap?['phone'],
      'customer': customerMap,
      'pickup': _fmtLocation(ride['pickup'], fallback: ride['pickupAddress']?.toString()),
      'dropoff': _fmtLocation(ride['drop'] ?? ride['dropoff'], fallback: ride['dropAddress']?.toString()),
      'distance': tripKm.toStringAsFixed(1),
      'tripDistanceKm': tripKm,
      'duration': '${(tripKm * 2).round()}',
      'fare': (ride['fare'] as num?)?.toDouble() ?? 0.0,
      'paymentMode': paymentMode,
      'status': (ride['status'] ?? 'SEARCHING_DRIVER').toString(),
      if (pickupLl != null) ...{
        'pickupLat': pickupLl.latitude,
        'pickupLng': pickupLl.longitude,
      },
      if (dropLl != null) ...{
        'dropLat': dropLl.latitude,
        'dropLng': dropLl.longitude,
      },
    };
    ui['nearPickupKm'] = ride['distance_to_pickup_km'] is num
        ? (ride['distance_to_pickup_km'] as num)
        : ride['distance_m'] is num
            ? (ride['distance_m'] as num) / 1000
            : _distanceKm(ui);
    return ui;
  }

  double _tripDistanceKm(
    Map<String, dynamic> ride,
    LatLng? pickupLl,
    LatLng? dropLl,
  ) {
    final stored = ride['distance_km'] ?? ride['actual_distance_km'];
    if (stored is num && stored > 0) return stored.toDouble();
    final distText = ride['distance']?.toString() ?? '';
    final parsed = double.tryParse(distText.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (parsed != null && parsed > 0) return parsed;
    if (pickupLl != null && dropLl != null) {
      return RideNavigationUtils.metersBetween(pickupLl, dropLl) / 1000;
    }
    return 0;
  }

  String _fmtLocation(dynamic loc, {String? fallback}) {
    if (loc is Map) {
      final address = loc['address']?.toString();
      if (address != null && address.isNotEmpty) return address;
      final lat = loc['lat'] ?? loc['latitude'];
      final lng = loc['lng'] ?? loc['longitude'];
      if (lat != null && lng != null) return '$lat, $lng';
    }
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return loc?.toString() ?? 'Unknown';
  }
}
