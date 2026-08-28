import 'package:flutter/foundation.dart';

/// Debug logging for the booking location flow (GPS → geocode → OSRM → API).
class LocationLogger {
  static void gps(String message, {double? lat, double? lng, double? accuracyM}) {
    if (!kDebugMode) return;
    final coords = lat != null && lng != null
        ? ' lat=$lat lng=$lng'
        : '';
    final acc = accuracyM != null ? ' accuracy=${accuracyM}m' : '';
    debugPrint('[Location/GPS] $message$coords$acc');
  }

  static void geocode(String message, {double? lat, double? lng, String? address}) {
    if (!kDebugMode) return;
    final coords = lat != null && lng != null ? ' ($lat, $lng)' : '';
    final addr = address != null ? ' → "$address"' : '';
    debugPrint('[Location/Geocode] $message$coords$addr');
  }

  static void osrm(String message, {
    double? pickupLat,
    double? pickupLng,
    double? dropLat,
    double? dropLng,
    double? distanceKm,
    double? durationMin,
    int? pointCount,
  }) {
    if (!kDebugMode) return;
    final route = pickupLat != null && dropLat != null
        ? ' pickup=($pickupLat,$pickupLng) drop=($dropLat,$dropLng)'
        : '';
    final metrics = distanceKm != null
        ? ' distance=${distanceKm}km duration=${durationMin ?? '?'}min points=$pointCount'
        : '';
    debugPrint('[Location/OSRM] $message$route$metrics');
  }

  static void booking(String message, {
    double? pickupLat,
    double? pickupLng,
    String? pickupAddress,
    double? dropLat,
    double? dropLng,
    String? dropAddress,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[Location/Booking] $message\n'
      '  pickup: ($pickupLat, $pickupLng) "$pickupAddress"\n'
      '  drop:   ($dropLat, $dropLng) "$dropAddress"',
    );
  }

  static void api(String message, {Map<String, dynamic>? payload}) {
    if (!kDebugMode) return;
    debugPrint('[Location/API] $message payload=$payload');
  }

  static void error(String context, Object error) {
    if (!kDebugMode) return;
    debugPrint('[Location/ERROR] $context: $error');
  }
}
