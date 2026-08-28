import 'package:latlong2/latlong.dart';

import 'navigation_logger.dart';

class RideNavigationUtils {
  static const _distance = Distance();

  static double metersBetween(LatLng a, LatLng b) {
    return _distance.as(LengthUnit.Meter, a, b);
  }

  static bool isValidCoord(double lat, double lng) {
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return false;
    return true;
  }

  /// Parses `"lat, lng"` strings from normalized ride lists.
  static LatLng? parseLatLngString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split(',');
    if (parts.length < 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    if (!isValidCoord(lat, lng)) return null;
    return LatLng(lat, lng);
  }

  /// Parses `{lat,lng}`, `{latitude,longitude}`, or nested ride pickup/drop maps.
  static LatLng? parseLatLng(dynamic value) {
    if (value is LatLng) return value;
    if (value is String) return parseLatLngString(value);
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final lat = map['lat'] ?? map['latitude'];
    final lng = map['lng'] ?? map['longitude'] ?? map['lon'];
    if (lat is! num || lng is! num) return null;
    final la = lat.toDouble();
    final lo = lng.toDouble();
    if (!isValidCoord(la, lo)) return null;
    return LatLng(la, lo);
  }

  /// Reads pickup/drop from ride payload (API or socket shapes).
  static LatLng? pickupFromRide(Map<String, dynamic> ride) {
    return parseLatLng(ride['pickup']) ??
        _fromFlatKeys(ride, 'pickupLat', 'pickupLng') ??
        _fromFlatKeys(ride, 'pickup_lat', 'pickup_lng');
  }

  static LatLng? dropFromRide(Map<String, dynamic> ride) {
    return parseLatLng(ride['drop']) ??
        parseLatLng(ride['dropoff']) ??
        _fromFlatKeys(ride, 'dropLat', 'dropLng') ??
        _fromFlatKeys(ride, 'drop_lat', 'drop_lng');
  }

  /// Fills flat lat/lng keys from nested maps or comma-separated labels.
  static Map<String, dynamic> ensureCoordinates(Map<String, dynamic> ride) {
    final map = Map<String, dynamic>.from(ride);
    final pickup = pickupFromRide(map);
    if (pickup != null) {
      map['pickupLat'] ??= pickup.latitude;
      map['pickupLng'] ??= pickup.longitude;
      if (map['pickup'] is! Map) {
        map['pickup'] = {'lat': pickup.latitude, 'lng': pickup.longitude};
      }
    }
    final drop = dropFromRide(map);
    if (drop != null) {
      map['dropLat'] ??= drop.latitude;
      map['dropLng'] ??= drop.longitude;
      if (map['drop'] is! Map && map['dropoff'] is! Map) {
        map['drop'] = {'lat': drop.latitude, 'lng': drop.longitude};
      }
    }
    return map;
  }

  static LatLng? _fromFlatKeys(Map<String, dynamic> map, String latKey, String lngKey) {
    final lat = map[latKey];
    final lng = map[lngKey];
    if (lat is! num || lng is! num) return null;
    final la = lat.toDouble();
    final lo = lng.toDouble();
    if (!isValidCoord(la, lo)) return null;
    return LatLng(la, lo);
  }

  static bool isNear(
    LatLng current,
    LatLng target, {
    double thresholdMeters = 100,
    bool log = false,
  }) {
    final meters = metersBetween(current, target);
    if (log) {
      NavigationLogger.arrival(
        meters <= thresholdMeters ? 'within geofence' : 'outside geofence',
        driverLat: current.latitude,
        driverLng: current.longitude,
        targetLat: target.latitude,
        targetLng: target.longitude,
        distanceM: meters,
      );
    }
    return meters <= thresholdMeters;
  }

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String formatEta(double durationMin) {
    if (durationMin < 1) return '< 1 min';
    return '${durationMin.round()} min';
  }

  /// True when two coordinates are the same place within [toleranceMeters].
  static bool samePlace(LatLng a, LatLng b, {double toleranceMeters = 50}) {
    return metersBetween(a, b) <= toleranceMeters;
  }
}
