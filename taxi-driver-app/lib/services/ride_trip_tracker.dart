import 'package:latlong2/latlong.dart';

import '../core/fare_calculator.dart';
import '../utils/ride_navigation_utils.dart';
import 'driver_location_service.dart';

/// Tracks actual GPS distance and duration during an active trip leg.
class RideTripTracker {
  static const _minSegmentMeters = 8.0;

  bool _tracking = false;
  DateTime? _startedAt;
  LatLng? _lastPoint;
  double _meters = 0;
  final List<LatLng> _path = <LatLng>[];

  bool get isTracking => _tracking;
  double get distanceKm => _meters / 1000;
  double get durationMin {
    if (_startedAt == null) return 0;
    return DateTime.now().difference(_startedAt!).inSeconds / 60;
  }
  List<LatLng> get path => List<LatLng>.unmodifiable(_path);

  void start({LatLng? from}) {
    _tracking = true;
    _startedAt = DateTime.now();
    _meters = 0;
    _path.clear();
    if (from != null) {
      _lastPoint = from;
      _path.add(from);
    }
  }

  void stop() => _tracking = false;

  void onFix(DriverGpsFix fix) {
    if (!_tracking) return;
    final point = fix.latLng;
    if (_lastPoint == null) {
      _lastPoint = point;
      _path.add(point);
      return;
    }
    final segment = RideNavigationUtils.metersBetween(_lastPoint!, point);
    if (segment < _minSegmentMeters) return;
    _meters += segment;
    _lastPoint = point;
    _path.add(point);
  }

  /// Actual trip fare — billed on GPS km only when customer gets off anywhere.
  double estimateKmOnlyFare({double? distanceKm, double? perKm}) {
    return FareCalculator.kmOnlyFare(
      distanceKm ?? this.distanceKm,
      ratePerKm: perKm,
    );
  }

  /// Dynamic fare: distance + time (1st min free, then ₹5/min).
  double estimateFare({double? distanceKm, double? durationMin, double? perKm}) {
    return FareCalculator.tripFare(
      distanceKm: distanceKm ?? this.distanceKm,
      durationMin: durationMin ?? this.durationMin,
      ratePerKm: perKm,
    );
  }
}
