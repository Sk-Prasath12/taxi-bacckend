import 'package:flutter/foundation.dart';

/// Debug logging for driver GPS, OSRM, WebSocket, and arrival detection.
class NavigationLogger {
  static void gps(String message, {
    double? lat,
    double? lng,
    double? speedKmh,
    double? heading,
  }) {
    if (!kDebugMode) return;
    final coords = lat != null && lng != null ? ' lat=$lat lng=$lng' : '';
    final extra = <String>[
      if (speedKmh != null) 'speed=${speedKmh.toStringAsFixed(1)}km/h',
      if (heading != null) 'heading=${heading.toStringAsFixed(0)}°',
    ].join(' ');
    debugPrint('[Nav/GPS] $message$coords${extra.isNotEmpty ? ' $extra' : ''}');
  }

  static void socket(String message, {
    String? rideId,
    double? lat,
    double? lng,
  }) {
    if (!kDebugMode) return;
    final coords = lat != null && lng != null ? ' ($lat,$lng)' : '';
    debugPrint('[Nav/Socket] $message ride=$rideId$coords');
  }

  static void osrm(String message, {
    double? fromLat,
    double? fromLng,
    double? toLat,
    double? toLng,
    double? distanceKm,
    double? durationMin,
    int? pointCount,
    String? server,
  }) {
    if (!kDebugMode) return;
    final route = fromLat != null && toLat != null
        ? ' ($fromLat,$fromLng)→($toLat,$toLng)'
        : '';
    final metrics = distanceKm != null
        ? ' ${distanceKm.toStringAsFixed(2)}km ${durationMin?.toStringAsFixed(1) ?? '?'}min pts=$pointCount'
        : '';
    final host = server != null ? ' via $server' : '';
    debugPrint('[Nav/OSRM] $message$route$metrics$host');
  }

  static void route(String message, {String? stage}) {
    if (!kDebugMode) return;
    debugPrint('[Nav/Route] $message${stage != null ? ' stage=$stage' : ''}');
  }

  static void arrival(String message, {
    double? driverLat,
    double? driverLng,
    double? targetLat,
    double? targetLng,
    double? distanceM,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[Nav/Arrival] $message driver=($driverLat,$driverLng) '
      'target=($targetLat,$targetLng) dist=${distanceM?.round()}m',
    );
  }

  static void error(String context, Object error) {
    if (!kDebugMode) return;
    debugPrint('[Nav/ERROR] $context: $error');
  }
}
