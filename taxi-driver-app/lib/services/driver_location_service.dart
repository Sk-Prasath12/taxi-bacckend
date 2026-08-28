import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../utils/navigation_logger.dart';

/// Real device GPS fixes for driver navigation (no simulated movement).
class DriverGpsFix {
  final double latitude;
  final double longitude;
  final double speedMps;
  final double heading;
  final DateTime timestamp;

  const DriverGpsFix({
    required this.latitude,
    required this.longitude,
    required this.speedMps,
    required this.heading,
    required this.timestamp,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  double get speedKmh => speedMps * 3.6;

  factory DriverGpsFix.fromPosition(Position position) {
    return DriverGpsFix(
      latitude: position.latitude,
      longitude: position.longitude,
      speedMps: position.speed >= 0 ? position.speed : 0,
      heading: position.heading >= 0 ? position.heading : 0,
      timestamp: position.timestamp,
    );
  }
}

class DriverLocationService {
  DriverLocationService._();
  static final DriverLocationService instance = DriverLocationService._();

  final _fixes = StreamController<DriverGpsFix>.broadcast();
  StreamSubscription<Position>? _subscription;
  DriverGpsFix? _latest;

  Stream<DriverGpsFix> get fixes => _fixes.stream;
  DriverGpsFix? get latest => _latest;

  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<DriverGpsFix?> getCurrentFix() async {
    if (!await ensurePermission()) return null;
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
    );
    final fix = DriverGpsFix.fromPosition(position);
    _latest = fix;
    return fix;
  }

  /// Fast fix for GO ONLINE — cached, last known, then short GPS timeout.
  Future<DriverGpsFix?> getFastFix() async {
    if (_latest != null) return _latest;

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        final fix = DriverGpsFix.fromPosition(last);
        _latest = fix;
        return fix;
      }
    } catch (_) {}

    if (!await ensurePermission()) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 1),
        ),
      );
      final fix = DriverGpsFix.fromPosition(position);
      _latest = fix;
      return fix;
    } catch (_) {
      return _latest;
    }
  }

  Future<void> startTracking() async {
    if (!await ensurePermission()) return;
    await stopTracking();
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((position) {
      final fix = DriverGpsFix.fromPosition(position);
      _latest = fix;
      NavigationLogger.gps(
        'device fix',
        lat: fix.latitude,
        lng: fix.longitude,
        speedKmh: fix.speedKmh,
        heading: fix.heading,
      );
      if (!_fixes.isClosed) {
        _fixes.add(fix);
      }
    });
  }

  Future<void> stopTracking() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    stopTracking();
    _fixes.close();
  }
}
