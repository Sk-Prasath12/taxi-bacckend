import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/active_ride_store.dart';
import '../../services/ride_service.dart';
import '../../services/route_service.dart';
import '../../services/session_service.dart';
import '../../services/socket_service.dart';
import '../../utils/device_gps.dart';
import '../../utils/fare_calculator.dart';
import '../../utils/phone_launcher.dart';
import '../../utils/ride_locations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_map_view.dart';

class LatLngTween extends Tween<LatLng> {
  LatLngTween({required super.begin, required super.end});

  @override
  LatLng lerp(double t) {
    final beginValue = begin!;
    final endValue = end!;
    return LatLng(
      beginValue.latitude + (endValue.latitude - beginValue.latitude) * t,
      beginValue.longitude + (endValue.longitude - beginValue.longitude) * t,
    );
  }
}

class RideTrackingScreen extends StatefulWidget {
  const RideTrackingScreen({super.key});

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _socket = SocketService.instance;
  final _routeService = RouteService();
  final MapController _mapController = MapController();

  /// Live driver GPS (seeded to pickup until first `driver_location` for this ride).
  LatLng? _currentPosition;
  LatLng? _targetPosition;
  LatLng? _driverPosition;
  double _driverBearing = 0;
  final ValueNotifier<DriverMarkerFrame?> _driverPositionNotifier =
      ValueNotifier<DriverMarkerFrame?>(null);
  final ValueNotifier<double> _routeProgressNotifier = ValueNotifier<double>(0);
  String rideStatus = '';
  double distanceKm = 0;
  int etaMin = 0;
  bool _completionNavigationTriggered = false;
  bool _trackingStopped = false;
  bool _routeLoading = false;
  bool _rideSocketListenersBound = false;
  void Function()? _socketReadyListener;
  bool _initialStatusFromRouteApplied = false;
  bool _initialDriverSeedDone = false;
  bool _initialSyncStarted = false;
  bool _rideDataLoading = true;
  Map<String, dynamic>? _latestRidePayload;
  final ValueNotifier<Map<String, dynamic>> _rideNotifier =
      ValueNotifier<Map<String, dynamic>>(<String, dynamic>{
    'status': '',
    'distanceKm': 0.0,
    'etaMin': 0,
    'driverName': '',
    'driverPhone': '',
    'driverId': null,
    'paymentMethod': 'Cash',
  });

  /// Filled from live `ride_status_update` when pickup/drop were missing from route args.
  LatLng? _pickupFromSocketStatus;
  LatLng? _dropFromSocketStatus;
  List<LatLng> _routePoints = const [];
  DateTime? _lastRouteRefreshAt;
  String driverName = '';
  String driverPhone = '';
  String? driverId;
  late final AnimationController _driverAnimationController;
  Animation<LatLng>? _driverPositionAnimation;
  Animation<double>? _driverBearingAnimation;
  LatLng? _oldPosition;
  LatLng? _newPosition;
  double _oldBearing = 0;
  double _newBearing = 0;
  void Function(dynamic)? _driverLocationListener;
  void Function(dynamic)? _rideStatusListener;
  void Function(dynamic)? _invoiceListener;
  void Function(dynamic)? _rideTrackingListener;
  void Function(dynamic)? _flexibleRideListener;
  Timer? _customerLocationTimer;
  Timer? _stageSyncTimer;

  String? _persistedPickupOtp;
  String? _persistedDropOtp;
  bool _pickupOtpVerified = false;
  bool _dropReachedFlag = false;
  bool _dropOtpVerified = false;
  bool _emergencySending = false;
  bool _emergencySent = false;

  bool get _isSearchingStage =>
      rideStatus == 'SEARCHING_DRIVER' || rideStatus == 'SEARCHING';
  bool get _isDriverAssignedStage =>
      rideStatus == 'DRIVER_ASSIGNED' ||
      rideStatus == 'ACCEPTED' ||
      rideStatus == 'DRIVER_ARRIVING';
  bool get _isDriverArrivedStage =>
      rideStatus == 'DRIVER_ARRIVED' ||
      rideStatus == 'ARRIVED_AT_PICKUP' ||
      rideStatus == 'ARRIVED';
  bool get _isTripNavigationStage =>
      rideStatus == 'OTP_VERIFIED' ||
      rideStatus == 'STARTED' ||
      rideStatus == 'PICKED_UP' ||
      rideStatus == 'IN_TRANSIT';
  bool get _showLiveDriver => !_isSearchingStage;
  bool get _navigationMode => _isTripNavigationStage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _driverAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(() {
        final animated = _driverPositionAnimation?.value;
        final animatedBearing = _driverBearingAnimation?.value;
        if (!mounted || animated == null) return;
        _driverPosition = animated;
        _currentPosition = animated;
        if (animatedBearing != null) {
          _driverBearing = animatedBearing;
        }
        if (_showLiveDriver) {
          _driverPositionNotifier.value = DriverMarkerFrame(
            position: animated,
            bearing: _driverBearing,
          );
        }
        _routeProgressNotifier.value = _computeRouteProgress(animated);
        _followDriverOnMap(animated, _driverBearing);
      });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _forceSync();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialStatusFromRouteApplied) {
      _initialStatusFromRouteApplied = true;
      _applyInitialStatusFromRouteArgs();
    }
    _seedInitialDriverAtPickup();
    _setupSocketOnce();
    _startStatusSyncIfNeeded();
    _refreshRoadRoute(force: true);
    _startRoadRouteRefreshLoop();
  }

  void _seedInitialDriverAtPickup() {
    if (_initialDriverSeedDone || !mounted) return;
    if (!_isDriverArrivedStage) return;
    _initialDriverSeedDone = true;
    final pickup = resolvePickupLatLng(_locationArgsMap());
    if (pickup == null || _driverPosition != null) return;
    _driverPosition = pickup;
    _currentPosition = pickup;
    _targetPosition = pickup;
    _driverPositionNotifier.value = DriverMarkerFrame(
      position: pickup,
      bearing: _driverBearing,
    );
    _oldPosition = pickup;
    _newPosition = pickup;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _followDriverOnMap(pickup, _driverBearing);
    });
  }

  double calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * (math.pi / 180);
    final lat2 = end.latitude * (math.pi / 180);
    final dLon = (end.longitude - start.longitude) * (math.pi / 180);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    return math.atan2(y, x) * (180 / math.pi);
  }

  void _followDriverOnMap(LatLng target, double bearing) {
    if (!_showLiveDriver) return;
    try {
      final zoom = _mapController.camera.zoom;
      final nextZoom = zoom < 16 ? 16.0 : zoom;
      _mapController.moveAndRotate(target, nextZoom, bearing);
    } catch (_) {
      // Map not attached yet; next location update will retry.
    }
  }

  double _computeRouteProgress(LatLng driver) {
    if (_routePoints.length < 2) return 0;
    final total = _routePoints.length - 1;
    int nearest = 0;
    double minM = double.infinity;
    const distance = Distance();
    for (var i = 0; i < _routePoints.length; i++) {
      final d = distance.as(LengthUnit.Meter, driver, _routePoints[i]);
      if (d < minM) {
        minM = d;
        nearest = i;
      }
    }
    return (nearest / total).clamp(0.0, 1.0);
  }

  void _animateDriverTo(LatLng target, double bearing) {
    final current = _driverPosition;
    if (current == null) {
      _oldPosition = target;
      _newPosition = target;
      _oldBearing = bearing;
      _newBearing = bearing;
      _driverPosition = target;
      _driverBearing = bearing;
      _driverPositionNotifier.value = DriverMarkerFrame(
        position: target,
        bearing: _driverBearing,
      );
      return;
    }

    _oldPosition = current;
    _newPosition = target;
    _oldBearing = _driverBearing;
    _newBearing = bearing;

    final tween = Tween<double>(begin: 0, end: 1);
    _driverPositionAnimation = tween
        .animate(
          CurvedAnimation(
            parent: _driverAnimationController,
            curve: Curves.easeInOut,
          ),
        )
        .drive(
          LatLngTween(
            begin: _oldPosition!,
            end: _newPosition!,
          ),
        );
    _driverBearingAnimation = Tween<double>(
      begin: _oldBearing,
      end: _newBearing,
    ).animate(
      CurvedAnimation(
        parent: _driverAnimationController,
        curve: Curves.linear,
      ),
    );

    _driverAnimationController
      ..stop()
      ..reset()
      ..forward();
  }

  void updateDriverLocation(LatLng newPosition) {
    if (!_showLiveDriver) return;
    if (_currentPosition == null) {
      _currentPosition = newPosition;
      _targetPosition = newPosition;
      _driverPosition = newPosition;
      _driverPositionNotifier.value = DriverMarkerFrame(
        position: newPosition,
        bearing: _driverBearing,
      );
      _routeProgressNotifier.value = _computeRouteProgress(newPosition);
      return;
    }

    final noiseDistanceMeters =
        const Distance().as(LengthUnit.Meter, _currentPosition!, newPosition);
    if (noiseDistanceMeters < 2) return;

    _targetPosition = newPosition;
    final computedBearing =
        calculateBearing(_currentPosition!, _targetPosition!);
    _driverBearing = computedBearing;
    _animateDriverTo(_targetPosition!, computedBearing);
  }

  void _applyInitialStatusFromRouteArgs() {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args == null) return;
    final routeOtp = args['otp'];
    if (_isRealRideOtp(routeOtp)) {
      _persistedPickupOtp = routeOtp.toString();
    }
    final statusPayload = args['statusPayload'] ?? args['initialData'];
    bool applied = false;
    if (statusPayload is Map) {
      final s = statusPayload['status']?.toString().toUpperCase();
      if (s != null && s.isNotEmpty) {
        final ride = statusPayload['ride'];
        final rideMap = ride is Map ? ride : null;
        final driverFromRide = rideMap?['driver'];
        final driverFromRoot = statusPayload['driver'];
        final driverMap = driverFromRide is Map
            ? driverFromRide
            : driverFromRoot is Map
                ? driverFromRoot
                : null;
        setState(() {
          rideStatus = s;
          driverName = driverMap?['name']?.toString() ??
              statusPayload['driver_name']?.toString() ??
              driverName;
          driverPhone = driverMap?['phone']?.toString() ??
              statusPayload['driver_phone']?.toString() ??
              driverPhone;
          driverId = driverMap?['id']?.toString() ??
              statusPayload['driver_id']?.toString() ??
              driverId;
        });
        applied = true;
      }
    }
    if (applied) return;
    final initialStatus = args['initialStatus']?.toString().toUpperCase();
    if (initialStatus != null && initialStatus.isNotEmpty) {
      setState(() => rideStatus = initialStatus);
      print('INITIAL STATUS: $rideStatus');
      return;
    }
    final directStatus = args['rideStatus']?.toString().toUpperCase();
    if (directStatus != null && directStatus.isNotEmpty) {
      setState(() => rideStatus = directStatus);
      print('INITIAL STATUS: $rideStatus');
      return;
    }
    if (args['acceptedPayload'] != null) {
      setState(() => rideStatus = 'ACCEPTED');
      print('INITIAL STATUS: $rideStatus');
    }
  }

  Map<String, dynamic>? _payloadAsMap(dynamic data) {
    final raw = data is List && data.isNotEmpty ? data.first : data;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Map<dynamic, dynamic>? _locationArgsMap() {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args == null) return null;
    return {
      ...args,
      if (_pickupFromSocketStatus != null)
        'pickupLatLng': _pickupFromSocketStatus,
      if (_dropFromSocketStatus != null) 'dropoffLatLng': _dropFromSocketStatus,
    };
  }

  bool _shouldRefreshRoadRouteForStatus(String status) {
    final normalized = status.toUpperCase();
    return normalized == 'ACCEPTED' ||
        normalized == 'DRIVER_ASSIGNED' ||
        normalized == 'DRIVER_ARRIVED' ||
        normalized == 'OTP_VERIFIED' ||
        normalized == 'ARRIVED' ||
        normalized == 'ARRIVED_AT_PICKUP' ||
        normalized == 'STARTED' ||
        normalized == 'PICKED_UP' ||
        normalized == 'IN_TRANSIT';
  }

  void _startRoadRouteRefreshLoop() {
    // No interval-based route reload to avoid periodic UI flicker.
  }

  Future<void> _refreshRoadRoute({bool force = false}) async {
    if (_trackingStopped) return;
    final args = _locationArgsMap();
    final pickupLatLng = resolvePickupLatLng(args);
    final dropoffLatLng = resolveDropLatLng(args);
    if (pickupLatLng == null || dropoffLatLng == null) return;
    if (_routeLoading) return;
    if (!force && !_shouldRefreshRoadRouteForStatus(rideStatus)) return;
    final now = DateTime.now();
    if (!force &&
        _lastRouteRefreshAt != null &&
        now.difference(_lastRouteRefreshAt!).inMilliseconds < 3500) {
      return;
    }

    final from = _driverPosition ?? pickupLatLng;
    final to = _navigationMode ? dropoffLatLng : pickupLatLng;
    if (to == null) return;

    _routeLoading = true;
    try {
      final pts = await _routeService.routeBetween(from, to);
      if (!mounted) return;
      if (_routePoints != pts) {
        setState(() => _routePoints = pts);
      }
      if (_driverPosition != null) {
        _routeProgressNotifier.value = _computeRouteProgress(_driverPosition!);
      }
      _lastRouteRefreshAt = now;
    } catch (e) {
      print('OSRM route error: $e');
    } finally {
      _routeLoading = false;
    }
  }

  void _stopLiveTracking() {
    if (_trackingStopped) return;
    _trackingStopped = true;
    _driverAnimationController.stop();
    final d = _driverLocationListener;
    if (d != null) _socket.offDriverLocation(d);
    _customerLocationTimer?.cancel();
    _customerLocationTimer = null;
  }

  void _startCustomerLocationUpdates(String rideId) {
    _customerLocationTimer?.cancel();
    _customerLocationTimer =
        Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final blocked = await DeviceGps.ensureReady();
        if (blocked != null) return;
        final pos = await DeviceGps.currentLatLng();
        _socket.emitCustomerLocation(
          lat: pos.latitude,
          lng: pos.longitude,
          rideId: rideId,
        );
      } catch (_) {}
    });
  }

  void _setupSocketOnce({bool force = false}) {
    if (_rideSocketListenersBound && !force) return;

    if (_socketReadyListener == null) {
      _socketReadyListener = () {
        if (!mounted) return;
        _setupSocketOnce(force: true);
      };
      _socket.onReady(_socketReadyListener!);
    }

    // Drop previous handlers before re-binding (socket recreate).
    final prevD = _driverLocationListener;
    final prevR = _rideStatusListener;
    final prevI = _invoiceListener;
    final prevT = _rideTrackingListener;
    final prevF = _flexibleRideListener;
    if (prevD != null) _socket.offDriverLocation(prevD);
    if (prevR != null) _socket.offRideStatusUpdate(prevR);
    if (prevI != null) _socket.offInvoiceGenerated(prevI);
    if (prevT != null) _socket.offRideTrackingUpdate(prevT);
    if (prevF != null) _socket.offPaymentSuccess(prevF);

    _rideSocketListenersBound = true;

    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final rideId = args?['rideId']?.toString();

    _socket.connect().then((_) {
      if (!mounted) return;
      _socket.joinCustomerRoom();
      if (rideId != null && rideId.isNotEmpty) {
        _socket.joinCustomerRide(rideId);
        _socket.joinRideRoom(rideId);
        _startCustomerLocationUpdates(rideId);
      }
    });

    if (rideId != null && rideId.isNotEmpty) {
      _socket.joinRideRoom(rideId);
    }

    _driverLocationListener = (data) {
      final payload = data is List && data.isNotEmpty ? data.first : data;
      if (!mounted || payload is! Map) return;
      final incomingRideId = payload['ride_id']?.toString();
      if (rideId != null &&
          rideId.isNotEmpty &&
          incomingRideId != null &&
          incomingRideId.isNotEmpty &&
          incomingRideId != rideId) {
        return;
      }
      final lat = payload['lat'];
      final lng = payload['lng'];
      if (lat is! num || lng is! num) return;
      final distanceRaw = payload['distance_km'];
      final etaRaw = payload['eta_min'];
      final etaSecRaw = payload['eta_sec'] ?? payload['eta_seconds'];
      final distance = switch (distanceRaw) {
        num value => value.toDouble(),
        String value => double.tryParse(value) ?? distanceKm,
        _ => distanceKm,
      };
      var eta = etaRaw is num ? etaRaw.toInt() : etaMin;
      if (distance <= 0.05) {
        eta = 0;
      }
      final etaSeconds = switch (etaSecRaw) {
        num value => value.toInt(),
        String value => int.tryParse(value) ?? (eta * 60),
        _ => eta * 60,
      };
      final next = LatLng(lat.toDouble(), lng.toDouble());
      updateDriverLocation(next);
      distanceKm = distance;
      etaMin = eta;
      final previous = _rideNotifier.value;
      final prevDistance = (previous['distanceKm'] as num?)?.toDouble() ?? 0.0;
      final prevEta = (previous['etaMin'] as num?)?.toInt() ?? 0;
      final prevEtaSec =
          (previous['etaSeconds'] as num?)?.toInt() ?? (prevEta * 60);
      final etaChangedEnough = (etaSeconds - prevEtaSec).abs() > 10;
      if ((distance - prevDistance).abs() > 0.03 || etaChangedEnough) {
        _rideNotifier.value = {
          ...previous,
          'distanceKm': distance,
          'etaMin': eta,
          'etaSeconds': etaSeconds,
        };
      }
      _refreshRoadRoute();
    };
    _rideStatusListener = (data) {
      if (!mounted) return;
      final payloadMap = _payloadAsMap(data);
      if (payloadMap == null) return;
      print('STATUS UPDATE: $payloadMap');
      final status = payloadMap['status']?.toString().toUpperCase() ?? '';
      print('SOCKET STATUS: $status');
      final ride = payloadMap['ride'];
      final rideMap = ride is Map ? ride : null;
      final driverFromRide = rideMap?['driver'];
      final driverFromRoot = payloadMap['driver'];
      final driverMap = driverFromRide is Map
          ? driverFromRide
          : driverFromRoot is Map
              ? driverFromRoot
              : null;
      final statusPickup = resolvePickupLatLng({'statusPayload': payloadMap});
      final statusDrop = resolveDropLatLng({'statusPayload': payloadMap});
      driverName = driverMap?['name']?.toString() ??
          payloadMap['driver_name']?.toString() ??
          driverName;
      driverPhone = driverMap?['phone']?.toString() ??
          payloadMap['driver_phone']?.toString() ??
          driverPhone;
      driverId = driverMap?['id']?.toString() ??
          payloadMap['driver_id']?.toString() ??
          driverId;
      if (statusPickup != null) _pickupFromSocketStatus = statusPickup;
      if (statusDrop != null) _dropFromSocketStatus = statusDrop;
      _rideNotifier.value = {
        ..._rideNotifier.value,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'driverId': driverId,
      };
      if (statusPickup != null || statusDrop != null) {
        _refreshRoadRoute(force: true);
      }
      _handleStatusUpdate(status, payloadMap);
    };
    _invoiceListener = (data) {
      if (!mounted) return;
      print('INVOICE: $data');
      final payload = data is List && data.isNotEmpty ? data.first : data;
      if (payload is! Map) return;
      final invoiceRideId = payload['ride_id']?.toString();
      if (invoiceRideId != null && invoiceRideId.isNotEmpty) {
        Navigator.pushReplacementNamed(context, '/ride-payment',
            arguments: {'rideId': invoiceRideId});
      }
    };
    _rideTrackingListener = (data) {
      if (!mounted) return;
      final payload = data is List && data.isNotEmpty ? data.first : data;
      if (payload is! Map) return;
      final incomingRideId = payload['rideId']?.toString();
      if (rideId != null &&
          rideId.isNotEmpty &&
          incomingRideId != null &&
          incomingRideId.isNotEmpty &&
          incomingRideId != rideId) {
        return;
      }
      final lat = payload['lat'];
      final lng = payload['lng'];
      if (lat is! num || lng is! num) return;
      updateDriverLocation(LatLng(lat.toDouble(), lng.toDouble()));
      final stage = payload['stage']?.toString().toUpperCase();
      if (stage != null && stage.isNotEmpty && stage != rideStatus) {
        _handleStatusUpdate(stage, Map<String, dynamic>.from(payload));
      }
    };
    // Defensive off() prevents duplicate listeners if this screen is recreated unexpectedly.
    _socket.offDriverLocation();
    _socket.offRideStatusUpdate();
    _socket.offInvoiceGenerated();
    _socket.offRideTrackingUpdate();
    _flexibleRideListener = (data) {
      if (!mounted) return;
      final payloadMap = _payloadAsMap(data);
      if (payloadMap == null) return;
      final incomingRideId = payloadMap['ride_id']?.toString();
      if (rideId != null &&
          rideId.isNotEmpty &&
          incomingRideId != null &&
          incomingRideId.isNotEmpty &&
          incomingRideId != rideId) {
        return;
      }
      var status = payloadMap['status']?.toString().toUpperCase() ?? '';
      if (status.isEmpty && payloadMap['drop_otp'] != null) {
        status = 'DROP_REACHED';
      } else if (status.isEmpty && payloadMap['drop_reached'] == true) {
        status = 'DROP_REACHED';
      } else if (status.isEmpty && payloadMap['drop_otp_verified'] == true) {
        status = 'DROP_OTP_VERIFIED';
      } else if (status.isEmpty &&
          payloadMap['payment_mode']?.toString().toUpperCase() == 'ONLINE' &&
          payloadMap['payment_status']?.toString().toUpperCase() == 'PENDING') {
        status = 'PAYMENT_PENDING';
      } else if (status.isEmpty && payloadMap['otp_verified'] == true) {
        status = 'STARTED';
      } else if (status.isEmpty && payloadMap['otp'] != null) {
        status = 'ARRIVED';
      } else if (status.isEmpty &&
          payloadMap['payment_status']?.toString().toUpperCase() == 'SUCCESS') {
        _absorbOtpFieldsFromData(Map<String, dynamic>.from(payloadMap));
        _latestRidePayload =
            _mergeRidePayload(Map<String, dynamic>.from(payloadMap));
        _publishRideUi();
        return;
      }
      if (status.isEmpty) return;
      final merged = <String, dynamic>{
        ...payloadMap,
        'status': status,
        'ride': payloadMap['ride'] is Map ? payloadMap['ride'] : payloadMap,
      };
      _handleStatusUpdate(status, merged);
    };
    _socket.onDriverLocation(_driverLocationListener!);
    _socket.onRideStatusUpdate(_rideStatusListener!);
    _socket.onInvoiceGenerated(_invoiceListener!);
    _socket.onRideTrackingUpdate(_rideTrackingListener!);
    _socket.onPaymentSuccess(_flexibleRideListener!);
  }

  void _startStatusSyncIfNeeded() {
    if (_initialSyncStarted) return;
    _initialSyncStarted = true;
    _forceSync();
    _syncStagePolling();
  }

  Future<void> _forceSync() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final rideId = args?['rideId']?.toString() ??
        _latestRidePayload?['ride_id']?.toString() ??
        '';
    if (rideId.isEmpty) return;
    try {
      final ride = await RideService.getRideStatus(rideId);
      if (!mounted) return;
      final status =
          (ride['client_status'] ?? ride['status'])?.toString().toUpperCase() ??
              '';
      print('FORCE SYNC STATUS: $status');
      _handleStatusUpdate(status, {...ride, 'ride': ride});
    } catch (e) {
      print('SYNC ERROR: $e');
    } finally {
      if (mounted) {
        setState(() => _rideDataLoading = false);
      }
    }
  }

  void _absorbOtpFieldsFromData(Map<String, dynamic> data) {
    final ride = data['ride'] is Map ? data['ride'] as Map : null;
    final pickupOtp = data['otp'] ?? ride?['otp'];
    final dropOtp = data['drop_otp'] ?? ride?['drop_otp'];
    if (_isRealRideOtp(pickupOtp)) _persistedPickupOtp = pickupOtp.toString();
    if (dropOtp != null) {
      _persistedDropOtp = dropOtp.toString();
      _dropReachedFlag = true;
    }
    if (data['otp_verified'] == true || ride?['otp_verified'] == true) {
      _pickupOtpVerified = true;
    }
    if (data['drop_reached'] == true || ride?['drop_reached'] == true) {
      _dropReachedFlag = true;
    }
    if (data['drop_otp_verified'] == true ||
        ride?['drop_otp_verified'] == true) {
      _dropOtpVerified = true;
    }
    final st = _statusFromPayload(data);
    if (st == 'STARTED' || st == 'OTP_VERIFIED' || st == 'TRIP_STARTED') {
      _pickupOtpVerified = true;
    }
    if (st == 'DROP_REACHED') _dropReachedFlag = true;
    if (st == 'DROP_OTP_VERIFIED' || st == 'PAYMENT_PENDING') {
      _dropOtpVerified = true;
    }
  }

  String _statusFromPayload(Map<String, dynamic> data) {
    final ride = data['ride'] is Map ? data['ride'] as Map : null;
    return (data['status'] ??
                data['client_status'] ??
                ride?['client_status'] ??
                ride?['status'])
            ?.toString()
            .toUpperCase() ??
        '';
  }

  Map<String, dynamic> _mergeRidePayload(Map<String, dynamic> data) {
    final prev = _latestRidePayload ?? <String, dynamic>{};
    final prevRide = prev['ride'] is Map
        ? Map<String, dynamic>.from(prev['ride'] as Map)
        : <String, dynamic>{};
    final newRide = data['ride'] is Map
        ? Map<String, dynamic>.from(data['ride'] as Map)
        : <String, dynamic>{};
    final mergedRide = <String, dynamic>{...prevRide, ...newRide};

    final pickupOtp =
        data['otp'] ?? newRide['otp'] ?? prev['otp'] ?? _persistedPickupOtp;
    final dropOtp = data['drop_otp'] ??
        newRide['drop_otp'] ??
        prev['drop_otp'] ??
        _persistedDropOtp;
    final otpVerified = _pickupOtpVerified ||
        data['otp_verified'] == true ||
        prev['otp_verified'] == true;
    final dropReached = _dropReachedFlag ||
        data['drop_reached'] == true ||
        prev['drop_reached'] == true;
    final dropVerified = _dropOtpVerified ||
        data['drop_otp_verified'] == true ||
        prev['drop_otp_verified'] == true;

    return <String, dynamic>{
      ...prev,
      ...data,
      if (pickupOtp != null) 'otp': pickupOtp,
      if (dropOtp != null) 'drop_otp': dropOtp,
      'otp_verified': otpVerified,
      'drop_reached': dropReached,
      'drop_otp_verified': dropVerified,
      'ride': <String, dynamic>{
        ...mergedRide,
        if (pickupOtp != null) 'otp': pickupOtp,
        if (dropOtp != null) 'drop_otp': dropOtp,
        'otp_verified': otpVerified,
        'drop_reached': dropReached,
        'drop_otp_verified': dropVerified,
      },
    };
  }

  String _resolveClientRideStatus(String incoming) {
    final upper = incoming.toUpperCase();
    // Never pin over terminal / payment statuses (was trapping users on DROP_REACHED).
    const terminal = {
      'COMPLETED',
      'CANCELLED',
      'CANCELLED_BY_CUSTOMER',
      'PAYMENT_PENDING',
      'DROP_OTP_VERIFIED',
    };
    if (terminal.contains(upper)) return upper;

    if (_dropOtpVerified) {
      if (upper == 'PAYMENT_PENDING') return 'PAYMENT_PENDING';
      if (upper == 'COMPLETED') return 'COMPLETED';
      return 'DROP_OTP_VERIFIED';
    }
    if (_dropReachedFlag && !_dropOtpVerified) {
      // Only keep DROP_REACHED while the trip is still mid-drop.
      if (upper.isEmpty ||
          upper == 'DROP_REACHED' ||
          upper == 'IN_TRANSIT' ||
          upper == 'STARTED' ||
          upper == 'IN_PROGRESS' ||
          upper == 'PICKED_UP') {
        return 'DROP_REACHED';
      }
    }
    if (_pickupOtpVerified &&
        (upper == 'ARRIVED' ||
            upper == 'ARRIVED_AT_PICKUP' ||
            upper == 'DRIVER_ARRIVED')) {
      return 'STARTED';
    }
    return upper;
  }

  void _publishRideUi() {
    _rideNotifier.value = {
      ..._rideNotifier.value,
      'status': rideStatus,
      'otpCode': _resolvedOtp(null),
      'otpTitle': _otpCardTitle,
      'otpSubtitle': _otpSubtitle,
      'showOtpCode': _shouldShowOtpCode,
      'paymentMethod': (_locationArgsMap()?['paymentMethod']?.toString() ??
          _rideNotifier.value['paymentMethod']),
    };
    setState(() {});
  }

  void _syncStagePolling() {
    final rideOver = _completionNavigationTriggered ||
        rideStatus == 'COMPLETED' ||
        rideStatus == 'CANCELLED' ||
        rideStatus == 'CANCELLED_BY_CUSTOMER';
    if (rideOver) {
      _stageSyncTimer?.cancel();
      _stageSyncTimer = null;
      return;
    }
    if (_stageSyncTimer != null) return;
    _stageSyncTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _forceSync());
  }

  void _handleStatusUpdate(String status, Map<String, dynamic> data) {
    if (!mounted) return;
    _absorbOtpFieldsFromData(data);
    final merged = _mergeRidePayload(data);
    final incoming = status.isNotEmpty ? status : _statusFromPayload(merged);
    rideStatus = _resolveClientRideStatus(incoming);
    _latestRidePayload = merged;
    _rideDataLoading = false;
    unawaited(RideService.cacheActiveRide({
      ...merged,
      'status': rideStatus,
      'ride_id': merged['ride_id'] ?? merged['id'],
      'id': merged['id'] ?? merged['ride_id'],
    }));
    _rideNotifier.value = {
      ..._rideNotifier.value,
      'status': rideStatus,
      'paymentMethod': (_locationArgsMap()?['paymentMethod']?.toString() ??
          _rideNotifier.value['paymentMethod']),
      'vehicle': data['vehicle']?.toString() ??
          (data['ride'] is Map
              ? (data['ride'] as Map)['vehicle']?.toString()
              : null) ??
          _rideNotifier.value['vehicle'] ??
          'Taxi',
    };
    if (!_showLiveDriver) {
      _driverPositionNotifier.value = null;
    } else if (_driverPosition != null) {
      _driverPositionNotifier.value = DriverMarkerFrame(
        position: _driverPosition!,
        bearing: _driverBearing,
      );
    }
    if (_isDriverArrivedStage) {
      final pickup = resolvePickupLatLng(_locationArgsMap());
      if (pickup != null) {
        _driverPosition = pickup;
        _currentPosition = pickup;
        _targetPosition = pickup;
        _driverPositionNotifier.value =
            DriverMarkerFrame(position: pickup, bearing: _driverBearing);
      }
    }
    print(
        'SCREEN STATUS: $rideStatus dropOtp=$_persistedDropOtp showDrop=$_showDropOtp');
    if (_shouldRefreshRoadRouteForStatus(rideStatus)) {
      _refreshRoadRoute(force: true);
    }
    _publishRideUi();
    _syncStagePolling();
    _handleRideUI(rideStatus, merged);
  }

  void _handleRideUI(String status, dynamic data) {
    if (!mounted) return;
    final upper = status.toUpperCase();

    if (upper == 'CANCELLED' || upper == 'CANCELLED_BY_CUSTOMER') {
      if (_completionNavigationTriggered) return;
      _completionNavigationTriggered = true;
      _stopLiveTracking();
      unawaited(ActiveRideStore.clear());
      unawaited(SessionService.clearRide());
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      return;
    }

    if ((upper == 'PAYMENT_PENDING' || upper == 'DROP_OTP_VERIFIED') &&
        !_completionNavigationTriggered) {
      _stopLiveTracking();
      _completionNavigationTriggered = true;
      _handlePayment();
      return;
    }

    if (upper == 'COMPLETED' && !_completionNavigationTriggered) {
      print('Ride completed - stopping tracking');
      _stopLiveTracking();
      _completionNavigationTriggered = true;
      final paymentStatus = (_latestRidePayload?['payment_status'] ??
              _rideMapFromPayload(_latestRidePayload)?['payment_status'] ??
              '')
          .toString()
          .toUpperCase();
      if (paymentStatus == 'SUCCESS' || paymentStatus == 'PAID') {
        _navigateToRideSummary();
      } else {
        _handlePayment();
      }
    }
  }

  Future<void> _navigateToRideSummary() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final rideId = args?['rideId']?.toString() ?? '';
    if (!mounted || rideId.isEmpty) return;
    Navigator.pushReplacementNamed(
      context,
      '/payment-success',
      arguments: {
        'rideId': rideId,
        'amount': _resolvedFare(args),
        'paymentMethod': _rideNotifier.value['paymentMethod'] ?? 'Cash',
        'status': 'COMPLETED',
        'distanceKm': _latestRidePayload?['actual_distance_km'] ??
            _rideMapFromPayload(_latestRidePayload)?['actual_distance_km'],
        'durationMin': _latestRidePayload?['actual_duration_min'] ??
            _rideMapFromPayload(_latestRidePayload)?['actual_duration_min'],
      },
    );
  }

  Map<String, dynamic>? _rideMapFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    final ride = payload['ride'];
    if (ride is Map<String, dynamic>) return ride;
    return null;
  }

  bool get _pickupOtpVerifiedFlag =>
      _pickupOtpVerified ||
      _latestRidePayload?['otp_verified'] == true ||
      _rideMapFromPayload(_latestRidePayload)?['otp_verified'] == true;

  bool get _dropOtpVerifiedFlag =>
      _dropOtpVerified ||
      _latestRidePayload?['drop_otp_verified'] == true ||
      _rideMapFromPayload(_latestRidePayload)?['drop_otp_verified'] == true;

  bool get _dropReachedActive =>
      _dropReachedFlag ||
      _latestRidePayload?['drop_reached'] == true ||
      _rideMapFromPayload(_latestRidePayload)?['drop_reached'] == true ||
      rideStatus.toUpperCase() == 'DROP_REACHED';

  bool _isRealRideOtp(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (!RegExp(r'^\d{4}$').hasMatch(text)) return false;
    return text != '1000';
  }

  bool get _showDropOtp {
    if (_dropOtpVerifiedFlag) return false;
    if (!_dropReachedActive && _persistedDropOtp == null) return false;
    final drop = _persistedDropOtp ??
        _latestRidePayload?['drop_otp']?.toString() ??
        _rideMapFromPayload(_latestRidePayload)?['drop_otp']?.toString();
    return drop != null && drop.isNotEmpty;
  }

  bool get _showPickupOtp {
    if (_pickupOtpVerifiedFlag || _showDropOtp) return false;
    if (_isSearchingStage) return false;
    return _isRealRideOtp(_persistedPickupOtp) ||
        _isRealRideOtp(_latestRidePayload?['otp']) ||
        _isRealRideOtp(_rideMapFromPayload(_latestRidePayload)?['otp']);
  }

  bool get _shouldShowOtpCode => _showPickupOtp || _showDropOtp;

  String _resolvedOtp(Map<dynamic, dynamic>? args) {
    final payloadRide = _rideMapFromPayload(_latestRidePayload);
    final statusPayload = args?['statusPayload'];
    final statusRide = statusPayload is Map && statusPayload['ride'] is Map
        ? Map<String, dynamic>.from(statusPayload['ride'] as Map)
        : null;
    if (_showDropOtp) {
      final dropOtp = _persistedDropOtp ??
          _latestRidePayload?['drop_otp']?.toString() ??
          payloadRide?['drop_otp']?.toString() ??
          statusRide?['drop_otp']?.toString();
      if (dropOtp != null && dropOtp.isNotEmpty) return dropOtp;
    }
    if (!_showPickupOtp) return '----';
    final otpValue = _persistedPickupOtp ??
        _latestRidePayload?['otp']?.toString() ??
        payloadRide?['otp']?.toString() ??
        statusRide?['otp']?.toString() ??
        args?['otp']?.toString();
    return _isRealRideOtp(otpValue) ? otpValue.toString() : '----';
  }

  String get _otpCardTitle {
    if (_showDropOtp) return 'Drop OTP';
    if (_showPickupOtp) return 'Pickup OTP';
    if (_dropOtpVerifiedFlag) return 'Drop OTP verified';
    if (_pickupOtpVerifiedFlag) return 'Trip in progress';
    return 'Ride OTP';
  }

  String get _otpSubtitle {
    if (_showDropOtp) return 'Share this Drop OTP with your driver';
    if (_showPickupOtp) {
      return _isDriverArrivedStage
          ? 'Share this Pickup OTP with your driver'
          : 'Share this Pickup OTP when your driver arrives';
    }
    if (_dropOtpVerifiedFlag)
      return 'Drop OTP verified — complete payment to finish';
    if (_pickupOtpVerifiedFlag) return 'Pickup verified — enjoy your ride';
    return 'OTP will appear when your driver is assigned';
  }

  double _resolvedFare(Map<dynamic, dynamic>? args) {
    final payloadRide = _rideMapFromPayload(_latestRidePayload);
    final statusPayload = args?['statusPayload'];
    final statusRide = statusPayload is Map && statusPayload['ride'] is Map
        ? Map<String, dynamic>.from(statusPayload['ride'] as Map)
        : null;
    final candidate = _latestRidePayload?['fare'] ??
        payloadRide?['fare'] ??
        statusRide?['fare'] ??
        args?['fare'];
    if (candidate is num && candidate > 0) return candidate.toDouble();
    if (candidate is String) {
      final parsed = double.tryParse(candidate);
      if (parsed != null && parsed > 0) return parsed;
    }
    // Fallback: calculate from OSRM distance at ₹30/km
    final distKm = (_latestRidePayload?['distance_km'] ??
        _latestRidePayload?['actual_distance_km'] ??
        args?['distanceKm']);
    if (distKm is num && distKm > 0) {
      return FareCalculator.calculateFare(distKm.toDouble());
    }
    return 0.0;
  }

  String getStatusText([String? statusInput]) {
    final effectiveStatus = (statusInput ?? rideStatus).toUpperCase();
    switch (effectiveStatus) {
      case 'SEARCHING':
      case 'SEARCHING_DRIVER':
        return 'Finding driver...';
      case 'ACCEPTED':
      case 'DRIVER_ASSIGNED':
        return 'Driver assigned';
      case 'ARRIVED':
      case 'DRIVER_ARRIVED':
      case 'ARRIVED_AT_PICKUP':
        return 'Driver arrived';
      case 'OTP_VERIFIED':
        return 'Trip started';
      case 'STARTED':
        return 'Ride started';
      case 'IN_TRANSIT':
      case 'PICKED_UP':
        return 'On the way';
      case 'DROP_REACHED':
        return 'Drop reached — share Drop OTP';
      case 'DROP_OTP_VERIFIED':
      case 'PAYMENT_PENDING':
        return 'Confirming payment';
      case 'COMPLETED':
        return 'Ride completed';
      default:
        return 'Finding driver...';
    }
  }

  Widget buildStatusUI(
      {String? statusInput, double? distanceInput, int? etaInput}) {
    final status = (statusInput ?? rideStatus).toUpperCase();
    final distanceValue = distanceInput ?? distanceKm;
    final etaValue = etaInput ?? etaMin;
    if (status == 'DRIVER_ASSIGNED' ||
        status == 'ACCEPTED' ||
        status == 'DRIVER_ARRIVING') {
      if (distanceValue <= 0.05 && status != 'ARRIVED') {
        return _buildEtaCard('Driver is nearby', 'Arriving shortly');
      }
      return _buildEtaCard(
        'Driver arriving in $etaValue min',
        '${distanceValue.toStringAsFixed(2)} km away',
      );
    }

    if (status == 'DRIVER_ARRIVED' ||
        status == 'ARRIVED' ||
        status == 'ARRIVED_AT_PICKUP') {
      return _buildEtaCard('Driver Arrived', 'Meet at pickup point');
    }

    if (status == 'OTP_VERIFIED' ||
        status == 'STARTED' ||
        status == 'IN_TRANSIT' ||
        status == 'PICKED_UP') {
      return _buildEtaCard('On the way',
          '${distanceValue.toStringAsFixed(2)} km to destination');
    }

    if (status == 'DROP_REACHED') {
      return _buildEtaCard('Drop reached', 'Share Drop OTP with driver');
    }

    if (status == 'DROP_OTP_VERIFIED' || status == 'PAYMENT_PENDING') {
      return _buildEtaCard(
          'Payment pending', 'Complete payment to finish ride');
    }

    if (status == 'COMPLETED') {
      return const SizedBox.shrink();
    }

    return const SizedBox.shrink();
  }

  Widget _buildEtaCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _driverDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_socketReadyListener != null) {
      _socket.offReady(_socketReadyListener!);
      _socketReadyListener = null;
    }
    final d = _driverLocationListener;
    final r = _rideStatusListener;
    final i = _invoiceListener;
    final t = _rideTrackingListener;
    final f = _flexibleRideListener;
    if (d != null) _socket.offDriverLocation(d);
    if (r != null) _socket.offRideStatusUpdate(r);
    if (i != null) _socket.offInvoiceGenerated(i);
    if (t != null) _socket.offRideTrackingUpdate(t);
    if (f != null) _socket.offPaymentSuccess(f);
    WidgetsBinding.instance.removeObserver(this);
    _customerLocationTimer?.cancel();
    _stageSyncTimer?.cancel();
    _driverAnimationController.dispose();
    _driverPositionNotifier.dispose();
    _routeProgressNotifier.dispose();
    _rideNotifier.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _handlePayment() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final rideId = args?['rideId']?.toString() ??
        _latestRidePayload?['ride_id']?.toString() ??
        _latestRidePayload?['id']?.toString() ??
        _rideMapFromPayload(_latestRidePayload)?['ride_id']?.toString() ??
        _rideMapFromPayload(_latestRidePayload)?['id']?.toString() ??
        '';
    if (rideId.isEmpty) {
      _completionNavigationTriggered = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open payment — missing ride id. Pull to sync.'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/ride-payment',
        arguments: {'rideId': rideId});
  }

  Future<void> _sendEmergencyAlert() async {
    if (_emergencySending || _emergencySent) return;
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final rideId = args?['rideId']?.toString() ??
        _latestRidePayload?['ride_id']?.toString() ??
        '';
    if (rideId.isEmpty) return;
    setState(() => _emergencySending = true);
    try {
      double? lat;
      double? lng;
      try {
        final pos = await DeviceGps.currentLatLng();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}
      await RideService.triggerEmergency(rideId, lat: lat, lng: lng);
      if (!mounted) return;
      setState(() {
        _emergencySent = true;
        _emergencySending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency alert sent to admin and driver'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _emergencySending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Emergency failed: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('UI BUILD STATUS: $rideStatus');
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final geo = RideGeoPoints.fromTrackingArgs(_locationArgsMap() ?? args,
        driverPosition: _driverPosition);
    final pickupLatLng = geo.pickup;
    final dropoffLatLng = geo.drop;
    final rideId = args?['rideId']?.toString() ?? '';
    final paymentMethod = args?['paymentMethod']?.toString() ?? 'Cash';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: _routeProgressNotifier,
                builder: (context, routeProgress, _) {
                  return Stack(
                    children: [
                      AppMapView(
                        mapController: _mapController,
                        pickup: pickupLatLng,
                        drop: dropoffLatLng,
                        driverListenable:
                            _showLiveDriver ? _driverPositionNotifier : null,
                        routePoints:
                            _routePoints.isNotEmpty ? _routePoints : null,
                        initialCenter: pickupLatLng ?? dropoffLatLng,
                        initialZoom: 13.5,
                        showRoute: !_isSearchingStage,
                        interactive: true,
                        routeProgress: routeProgress,
                        navigationMode: _navigationMode,
                      ),
                      if (_routeLoading && _navigationMode)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              color: AppTheme.background.withValues(alpha: 0.45),
                              child: const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppTheme.primary)),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            ValueListenableBuilder<Map<String, dynamic>>(
              valueListenable: _rideNotifier,
              builder: (context, rideUi, _) {
                final statusText =
                    (rideUi['status']?.toString().isNotEmpty == true)
                        ? rideUi['status'].toString()
                        : rideStatus;
                final distanceUi =
                    (rideUi['distanceKm'] as num?)?.toDouble() ?? distanceKm;
                final etaUi = (rideUi['etaMin'] as num?)?.toInt() ?? etaMin;
                final driverNameUi =
                    rideUi['driverName']?.toString() ?? driverName;
                final driverPhoneUi =
                    rideUi['driverPhone']?.toString() ?? driverPhone;
                final driverIdUi = rideUi['driverId']?.toString() ?? driverId;
                final otpTitle =
                    rideUi['otpTitle']?.toString() ?? _otpCardTitle;
                final otpCode =
                    rideUi['otpCode']?.toString() ?? _resolvedOtp(args);
                final otpSubtitle =
                    rideUi['otpSubtitle']?.toString() ?? _otpSubtitle;
                final showOtpCode =
                    rideUi['showOtpCode'] == true || _shouldShowOtpCode;
                final fare = _resolvedFare(args);
                return Stack(
                  children: [
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x662563EB),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          getStatusText(statusText),
                          style: const TextStyle(
                            color: AppTheme.onPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 72,
                      child: buildStatusUI(
                        statusInput: statusText,
                        distanceInput: distanceUi,
                        etaInput: etaUi,
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Container(
                        decoration: AppTheme.cardDecoration(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              otpTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (_rideDataLoading)
                              const SizedBox(
                                height: 36,
                                child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppTheme.primary)),
                              )
                            else if (showOtpCode)
                              Text(
                                otpCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 30,
                                  color: AppTheme.primary,
                                ),
                              )
                            else
                              Text(
                                otpSubtitle,
                                style: const TextStyle(color: AppTheme.textSecondary),
                              ),
                            if (showOtpCode)
                              Text(
                                otpSubtitle,
                                style: const TextStyle(color: AppTheme.textSecondary),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              'Ride ID: $rideId',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              fare > 0
                                  ? 'Fare: ₹${fare.toStringAsFixed(0)}'
                                  : 'Fare: ₹0',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Payment: $paymentMethod',
                              style: const TextStyle(color: AppTheme.textSecondary),
                            ),
                            if (!_isSearchingStage) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: (_emergencySending || _emergencySent)
                                      ? null
                                      : _sendEmergencyAlert,
                                  icon: const Icon(Icons.emergency_share, color: AppTheme.danger),
                                  label: Text(
                                    _emergencySent
                                        ? 'Emergency alert sent'
                                        : (_emergencySending
                                            ? 'Sending emergency…'
                                            : 'SOS / Emergency'),
                                    style: const TextStyle(
                                      color: AppTheme.danger,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.danger),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                            if (_isDriverAssignedStage ||
                                _isDriverArrivedStage) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Driver assigned',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryLight,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _driverDetailRow(
                                      Icons.person_outline,
                                      driverNameUi.isNotEmpty
                                          ? driverNameUi
                                          : 'Driver details loading…',
                                    ),
                                    _driverDetailRow(
                                      Icons.local_taxi_outlined,
                                      'Vehicle: ${(rideUi['vehicle']?.toString() ?? 'Taxi')}',
                                    ),
                                    _driverDetailRow(
                                      Icons.schedule,
                                      'ETA: ${etaUi <= 0 ? 'Arriving' : '$etaUi min'}',
                                    ),
                                    _driverDetailRow(
                                      Icons.straighten,
                                      'Distance: ${distanceUi.toStringAsFixed(2)} km away',
                                    ),
                                    if (driverPhoneUi.isNotEmpty) ...[
                                      _driverDetailRow(Icons.phone_outlined, driverPhoneUi),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () async {
                                                final ok = await dialPhoneNumber(driverPhoneUi);
                                                if (!ok && context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Could not dial $driverPhoneUi'),
                                                    ),
                                                  );
                                                }
                                              },
                                              icon: const Icon(Icons.call),
                                              label: const Text('Call Driver'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () async {
                                                final ok = await smsPhoneNumber(driverPhoneUi);
                                                if (!ok && context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Could not open SMS for $driverPhoneUi'),
                                                    ),
                                                  );
                                                }
                                              },
                                              icon: const Icon(Icons.sms_outlined),
                                              label: const Text('Text'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    _driverDetailRow(
                                      Icons.info_outline,
                                      'Status: ${getStatusText(statusText)}',
                                    ),
                                    if (driverIdUi != null && driverIdUi.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Driver ID: $driverIdUi',
                                          style: const TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 52,
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: AppTheme.onPrimary,
                                  disabledBackgroundColor: AppTheme.surfaceLight,
                                  disabledForegroundColor: AppTheme.textMuted,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed:
                                    statusText.toUpperCase() == 'COMPLETED'
                                        ? _handlePayment
                                        : null,
                                child: Text(
                                  statusText.toUpperCase() == 'COMPLETED'
                                      ? 'VIEW INVOICE'
                                      : 'WAITING FOR RIDE COMPLETION',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
