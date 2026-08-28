import 'package:latlong2/latlong.dart';

/// Tamil Nadu service box (pickup + drop must be inside).
class ChennaiArea {
  // Keep Chennai as default map fallback center for a better first load.
  static const LatLng center = LatLng(13.0827, 80.2707);

  static const double minLat = 8.0;
  static const double maxLat = 13.9;
  static const double minLng = 76.0;
  static const double maxLng = 80.45;

  static bool contains(double lat, double lng) {
    return lat >= minLat &&
        lat <= maxLat &&
        lng >= minLng &&
        lng <= maxLng;
  }

  static bool containsLatLng(LatLng point) =>
      contains(point.latitude, point.longitude);

  /// Emulator / out-of-state GPS is replaced with app default center.
  static LatLng inServiceOrFallback(LatLng point) {
    return containsLatLng(point) ? point : center;
  }

  static String get outOfAreaMessage =>
      'This app serves Tamil Nadu only. Choose pickup and drop inside Tamil Nadu.';
}
