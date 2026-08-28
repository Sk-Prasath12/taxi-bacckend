import 'dart:math' as math;

import 'chennai_area.dart';

/// Validates latitude/longitude before ride booking.
bool isValidCoordinate(double lat, double lng) {
  if (!lat.isFinite || !lng.isFinite) return false;
  if (lat < -90 || lat > 90) return false;
  if (lng < -180 || lng > 180) return false;
  return true;
}

/// Rejects null-island and obviously invalid zero coordinates.
bool isUsableRideCoordinate(double lat, double lng) {
  if (!isValidCoordinate(lat, lng)) return false;
  if (lat == 0 && lng == 0) return false;
  return true;
}

double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) *
          math.cos(_toRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double _toRad(double deg) => deg * math.pi / 180;

bool isSameLocation(
  double lat1,
  double lng1,
  double lat2,
  double lng2, {
  double thresholdMeters = 25,
}) {
  return distanceMeters(lat1, lng1, lat2, lng2) <= thresholdMeters;
}

/// Detects common lat/lng field swap (e.g. lng stored as lat).
String? detectCoordinateFieldSwap(double lat, double lng, String label) {
  if (lat.abs() > 90 || lng.abs() > 180) {
    return '$label coordinates are out of range — latitude and longitude may be swapped.';
  }
  // Heuristic: lat should generally be smaller in magnitude than lng for most of Asia/Europe
  // when values are accidentally swapped (e.g. Chennai lng~80 stored as lat).
  if (lat.abs() > 60 && lng.abs() < lat.abs()) {
    return '$label looks swapped — check latitude and longitude order.';
  }
  return null;
}

String? validatePickupDrop({
  required double? pickupLat,
  required double? pickupLng,
  required double? dropLat,
  required double? dropLng,
}) {
  if (pickupLat == null || pickupLng == null) {
    return 'Pickup location is required.';
  }
  if (dropLat == null || dropLng == null) {
    return 'Drop location is required.';
  }
  if (!isUsableRideCoordinate(pickupLat, pickupLng)) {
    return 'Pickup coordinates are invalid.';
  }
  if (!isUsableRideCoordinate(dropLat, dropLng)) {
    return 'Drop coordinates are invalid.';
  }

  final pickupSwap = detectCoordinateFieldSwap(pickupLat, pickupLng, 'Pickup');
  if (pickupSwap != null) return pickupSwap;
  final dropSwap = detectCoordinateFieldSwap(dropLat, dropLng, 'Drop');
  if (dropSwap != null) return dropSwap;
  if (isSameLocation(pickupLat, pickupLng, dropLat, dropLng)) {
    return 'Pickup and drop cannot be the same location.';
  }
  if (!ChennaiArea.contains(pickupLat, pickupLng)) {
    return ChennaiArea.outOfAreaMessage;
  }
  if (!ChennaiArea.contains(dropLat, dropLng)) {
    return ChennaiArea.outOfAreaMessage;
  }
  return null;
}
