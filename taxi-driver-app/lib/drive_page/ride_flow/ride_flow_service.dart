import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxiapp/api/driver_api.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/services/active_ride_store.dart';
import 'package:taxiapp/services/driver_location_service.dart';
import 'package:taxiapp/services/driver_socket_service.dart';
import 'package:taxiapp/services/osrm_service.dart';
import 'package:taxiapp/services/ride_trip_tracker.dart';
import 'package:taxiapp/utils/ride_navigation_utils.dart';

/// Shared ride state, GPS, OSRM navigation, WebSocket for all ride-flow pages.
class RideFlowService {
  RideFlowService._();
  static final RideFlowService instance = RideFlowService._();

  final DriverSocketService socket = DriverSocketService();
  final DriverLocationService location = DriverLocationService.instance;
  final OsrmService osrm = OsrmService();
  final RideTripTracker tripTracker = RideTripTracker();

  final ValueNotifier<Map<String, dynamic>> rideNotifier =
      ValueNotifier<Map<String, dynamic>>(<String, dynamic>{});

  StreamSubscription<DriverGpsFix>? _gpsSub;
  StreamSubscription<Map<String, dynamic>>? _rideUpdateSub;
  StreamSubscription<Map<String, dynamic>>? _paymentSuccessSub;
  StreamSubscription<Map<String, dynamic>>? _paymentFailedSub;
  StreamSubscription<Map<String, dynamic>>? _rideCompletedSub;
  Timer? _routeRefreshTimer;

  LatLng? currentLocation;
  double heading = 0;
  List<LatLng> routePolyline = <LatLng>[];
  List<OsrmNavStep> navSteps = <OsrmNavStep>[];
  int currentStepIndex = 0;
  double routeDistanceKm = 0;
  double routeEtaMin = 0;
  LatLng? pickup;
  LatLng? drop;

  static const double pickupGeofenceM = 200;
  static const double dropGeofenceM = 200;

  /// Driver GPS, or pickup/drop fallback when GPS unavailable (e.g. web testing).
  LatLng? get effectiveLocation =>
      currentLocation ?? pickup ?? drop;

  Map<String, dynamic> get ride => rideNotifier.value;

  String get rideId =>
      (ride['id'] ?? ride['ride_id'] ?? ride['_id'] ?? '').toString();

  String get status => (ride['status'] ?? 'DRIVER_ASSIGNED').toString().toUpperCase();

  OsrmNavStep? get currentNavStep =>
      navSteps.isEmpty ? null : navSteps[currentStepIndex.clamp(0, navSteps.length - 1)];

  bool get isNearPickup {
    if (pickup == null) return false;
    final loc = effectiveLocation;
    if (loc == null) return routeDistanceKm < 0.25;
    if (RideNavigationUtils.samePlace(loc, pickup!)) return true;
    if (RideNavigationUtils.isNear(loc, pickup!, thresholdMeters: pickupGeofenceM)) {
      return true;
    }
    return routeDistanceKm < 0.15;
  }

  bool get isNearDrop {
    if (drop == null) return false;
    final loc = effectiveLocation;
    if (loc == null) return routeDistanceKm < 0.25;
    if (RideNavigationUtils.samePlace(loc, drop!)) return true;
    if (RideNavigationUtils.isNear(loc, drop!, thresholdMeters: dropGeofenceM)) {
      return true;
    }
    return routeDistanceKm < 0.15;
  }

  /// Returns a valid JWT for ride APIs; refreshes once if missing/expired.
  Future<String?> requireToken() async {
    final auth = AuthService();
    var token = auth.token;
    if (token != null && token.isNotEmpty) return token;
    if (await auth.refreshAccessToken()) return auth.token;
    return null;
  }

  void prepareRide(Map<String, dynamic> rideData) {
    var map = RideNavigationUtils.ensureCoordinates(Map<String, dynamic>.from(rideData));
    map['id'] = (map['id'] ?? map['ride_id'] ?? map['_id'] ?? '').toString();
    rideNotifier.value = map;
    _applyCoordinates();
  }

  Future<void> startBackgroundServices() async {
    if (pickup == null || drop == null) {
      await mergeFromServer();
    }
    await connectSocket();
    await location.startTracking();
    _gpsSub?.cancel();
    _gpsSub = location.fixes.listen(_onGpsFix);
    final fix = await location.getCurrentFix();
    if (fix != null) {
      currentLocation = fix.latLng;
      heading = fix.heading;
    } else if (currentLocation == null && pickup != null) {
      currentLocation = pickup;
    }
    final s = status;
    if ((ride['otp_verified'] == true || s == 'IN_TRANSIT' || s == 'PICKED_UP') &&
        !tripTracker.isTracking) {
      tripTracker.start(from: currentLocation);
    }
    _rideUpdateSub?.cancel();
    _rideUpdateSub = socket.rideUpdateStream.listen((payload) {
      final raw = payload['ride'] is Map
          ? Map<String, dynamic>.from(payload['ride'] as Map)
          : Map<String, dynamic>.from(payload);
      final id = (raw['rideId'] ?? raw['id'] ?? raw['ride_id'] ?? payload['ride_id'] ?? '')
          .toString();
      if (id.isNotEmpty && id != rideId) return;
      final rideMap = Map<String, dynamic>.from(raw);
      if (payload['drop_otp'] != null) rideMap['drop_otp'] = payload['drop_otp'];
      if (payload['drop_reached'] == true) rideMap['drop_reached'] = true;
      if (payload['payment_status'] != null) rideMap['payment_status'] = payload['payment_status'];
      if (payload['paymentStatus'] != null) rideMap['payment_status'] = payload['paymentStatus'];
      mergeRide(rideMap);
      save();
    });
    _paymentSuccessSub?.cancel();
    _paymentFailedSub?.cancel();
    _rideCompletedSub?.cancel();
    _paymentSuccessSub = socket.paymentSuccessStream.listen((payload) {
      final id = (payload['ride_id'] ?? payload['rideId'] ?? '').toString();
      if (id.isNotEmpty && id != rideId) return;
      final bal = payload['wallet_balance'];
      final earnings = payload['driver_earnings'];
      mergeRide({
        ...ride,
        'payment_status': 'SUCCESS',
        'status': payload['status'] ?? 'COMPLETED',
        if (bal is num) 'wallet_balance': bal.toDouble(),
        if (earnings is num) 'driver_earnings': earnings.toDouble(),
      });
      save();
    });
    _paymentFailedSub = socket.paymentFailedStream.listen((payload) {
      final id = (payload['ride_id'] ?? payload['rideId'] ?? '').toString();
      if (id.isNotEmpty && id != rideId) return;
      mergeRide({...ride, 'payment_status': 'FAILED'});
      save();
    });
    _rideCompletedSub = socket.rideCompletedStream.listen((payload) {
      final id = (payload['ride_id'] ?? payload['rideId'] ?? '').toString();
      if (id.isNotEmpty && id != rideId) return;
      final bal = payload['wallet_balance'];
      final earnings = payload['driver_earnings'];
      mergeRide({
        ...ride,
        'status': payload['status'] ?? 'COMPLETED',
        'payment_status': payload['payment_status'] ?? payload['paymentStatus'] ?? 'SUCCESS',
        if (bal is num) 'wallet_balance': bal.toDouble(),
        if (earnings is num) 'driver_earnings': earnings.toDouble(),
      });
      save();
    });
    await save();
    await loadRoute(toPickup: _shouldRouteToPickup());
  }

  Future<void> init(Map<String, dynamic> rideData) async {
    prepareRide(rideData);
    await startBackgroundServices();
  }

  bool _shouldRouteToPickup() {
    final s = status;
    return s != 'IN_TRANSIT' &&
        s != 'PICKED_UP' &&
        s != 'DROPPED' &&
        s != 'COMPLETED_PENDING_PAYMENT' &&
        s != 'COMPLETED';
  }

  void _applyCoordinates() {
    pickup = RideNavigationUtils.pickupFromRide(ride);
    drop = RideNavigationUtils.dropFromRide(ride);
  }

  /// Fetch live GPS now, refresh OSRM route, return driver position for map centering.
  Future<LatLng?> refreshDriverLocation() async {
    final fix = await location.getFastFix();
    if (fix != null) {
      currentLocation = fix.latLng;
      heading = fix.heading;
      tripTracker.onFix(fix);
      if (rideId.isNotEmpty) {
        socket.updateLocationForRide(
          rideId: rideId,
          lat: fix.latitude,
          lng: fix.longitude,
          speedKmh: fix.speedKmh,
          heading: fix.heading,
        );
      }
    } else if (currentLocation == null && pickup != null) {
      currentLocation = pickup;
    }
    await loadRoute(toPickup: _shouldRouteToPickup());
    _pulse();
    return currentLocation ?? pickup ?? drop;
  }

  Future<void> connectSocket() async {
    final token = await requireToken();
    final driverId = AuthService().driverId;
    if (token == null || driverId == null || driverId.isEmpty) return;

    final fix = await location.getCurrentFix();
    final lat = fix?.latitude ?? currentLocation?.latitude ?? pickup?.latitude ?? 0.0;
    final lng = fix?.longitude ?? currentLocation?.longitude ?? pickup?.longitude ?? 0.0;

    await socket.connect(
      token: token,
      driverId: driverId,
      lat: lat,
      lng: lng,
    );
    if (rideId.isNotEmpty) socket.joinRideRoom(rideId);
  }

  void _onGpsFix(DriverGpsFix fix) {
    currentLocation = fix.latLng;
    heading = fix.heading;
    tripTracker.onFix(fix);
    if (rideId.isNotEmpty) {
      socket.updateLocationForRide(
        rideId: rideId,
        lat: fix.latitude,
        lng: fix.longitude,
        speedKmh: fix.speedKmh,
        heading: fix.heading,
      );
    }
    _updateNavStep(fix.latLng);
    _scheduleRouteRefresh();
    _pulse();
  }

  void _updateNavStep(LatLng driver) {
    if (navSteps.isEmpty) return;
    var best = currentStepIndex;
    var bestDist = double.infinity;
    for (var i = 0; i < navSteps.length; i++) {
      final d = RideNavigationUtils.metersBetween(driver, navSteps[i].location);
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    if (bestDist < 30 && best < navSteps.length - 1) best++;
    if (best != currentStepIndex) {
      currentStepIndex = best;
    }
  }

  void _scheduleRouteRefresh() {
    _routeRefreshTimer?.cancel();
    _routeRefreshTimer = Timer(const Duration(seconds: 8), () async {
      _routeRefreshTimer = null;
      if (pickup == null || drop == null) return;
      await loadRoute(toPickup: _shouldRouteToPickup());
    });
  }

  void _pulse() {
    rideNotifier.value = Map<String, dynamic>.from(rideNotifier.value);
  }

  Future<void> mergeFromServer() async {
    final token = await requireToken();
    if (token == null || rideId.isEmpty) return;
    final remote = await DriverApi.withToken(token).findRideInHistory(rideId);
    if (remote != null) mergeRide(remote);
  }

  void mergeRide(Map<String, dynamic> remote) {
    final map = Map<String, dynamic>.from(ride);
    remote.forEach((key, value) {
      if (value != null) map[key] = value;
    });
    map['id'] = rideId;
    rideNotifier.value = RideNavigationUtils.ensureCoordinates(map);
    _applyCoordinates();
  }

  Future<void> save() async {
    await ActiveRideStore.save(ride);
  }

  Future<void> loadRoute({required bool toPickup}) async {
    final target = toPickup ? pickup : drop;
    var from = currentLocation ?? await location.getCurrentFix().then((f) => f?.latLng);
    from ??= toPickup ? pickup : drop;
    if (from == null || target == null) return;

    final straightM = RideNavigationUtils.metersBetween(from, target);
    if (straightM < 40) {
      routePolyline = [from, target];
      routeDistanceKm = straightM / 1000;
      routeEtaMin = 0;
      navSteps = [
        OsrmNavStep(
          location: target,
          instruction: toPickup ? 'You are at pickup — swipe to confirm ARRIVED' : 'You are at drop — swipe to confirm',
          distanceMeters: straightM,
          maneuverType: 'arrive',
        ),
      ];
      currentStepIndex = 0;
      if (currentLocation == null) currentLocation = from;
      _pulse();
      return;
    }

    final result = await osrm.getRoute(from: from, to: target);
    if (result != null) {
      routePolyline = result.points;
      routeDistanceKm = result.distanceKm;
      routeEtaMin = result.durationMin;
      navSteps = result.steps;
      currentStepIndex = 0;
      if (currentLocation != null) _updateNavStep(currentLocation!);
    } else {
      routePolyline = [from, target];
      routeDistanceKm = RideNavigationUtils.metersBetween(from, target) / 1000;
      routeEtaMin = routeDistanceKm * 2.5;
      navSteps = [
        OsrmNavStep(
          location: target,
          instruction: toPickup ? 'Head to pickup location' : 'Head to drop location',
          distanceMeters: routeDistanceKm * 1000,
        ),
      ];
      currentStepIndex = 0;
    }
    _pulse();
  }

  String customerName() {
    if (ride['customer'] is Map) {
      return (ride['customer'] as Map)['name']?.toString() ?? 'Customer';
    }
    return ride['passengerName']?.toString() ?? 'Customer';
  }

  String customerPhone() {
    if (ride['customer'] is Map) {
      return (ride['customer'] as Map)['phone']?.toString() ?? '';
    }
    return ride['customer_phone']?.toString() ?? ride['customerPhone']?.toString() ?? '';
  }

  String locationLabel(dynamic value, {required String fallback}) {
    if (value is Map) {
      final address = value['address']?.toString();
      if (address != null && address.isNotEmpty) return address;
    }
    final text = value?.toString();
    if (text != null && text.isNotEmpty && text != 'null') return text;
    return fallback;
  }

  double get billableTripKm {
    final tracked = tripTracker.distanceKm;
    if (tracked >= 0.05) return tracked;
    final from = pickup;
    final to = currentLocation ?? drop;
    if (from != null && to != null) {
      return (RideNavigationUtils.metersBetween(from, to) / 1000).clamp(0.1, double.infinity);
    }
    if (routeDistanceKm >= 0.1) return routeDistanceKm;
    return 0.1;
  }

  double get fare {
    final stored = (ride['fare'] as num?)?.toDouble();
    if (stored != null && stored > 0) return stored;
    return tripTracker.estimateKmOnlyFare(distanceKm: billableTripKm);
  }

  /// Clears ride navigation state and stops ride-only services (keeps login token).
  void disposeFlow() {
    _routeRefreshTimer?.cancel();
    _routeRefreshTimer = null;
    _gpsSub?.cancel();
    _gpsSub = null;
    _rideUpdateSub?.cancel();
    _rideUpdateSub = null;
    _paymentSuccessSub?.cancel();
    _paymentSuccessSub = null;
    _paymentFailedSub?.cancel();
    _paymentFailedSub = null;
    _rideCompletedSub?.cancel();
    _rideCompletedSub = null;
    tripTracker.stop();
    _clearNavigationState();
  }

  void _clearNavigationState() {
    currentLocation = null;
    heading = 0;
    routePolyline = <LatLng>[];
    navSteps = <OsrmNavStep>[];
    currentStepIndex = 0;
    routeDistanceKm = 0;
    routeEtaMin = 0;
    pickup = null;
    drop = null;
  }
}
