import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/env_config.dart';
import '../utils/location_logger.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMin;

  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
  });
}

class RouteService {
  static const _publicOsrm = 'https://router.project-osrm.org';

  String get _primaryOsrm {
    final fromEnv = EnvConfig.osrmUrl;
    if (fromEnv.isNotEmpty) return fromEnv.replaceAll(RegExp(r'/$'), '');
    return _publicOsrm;
  }

  /// OSRM driving route between two points.
  Future<List<LatLng>> routeBetween(LatLng from, LatLng to) async {
    final result = await getRouteWithMetrics(
      startLat: from.latitude,
      startLng: from.longitude,
      endLat: to.latitude,
      endLng: to.longitude,
    );
    return result?.points ?? <LatLng>[];
  }

  Future<RouteResult?> getRouteWithMetrics({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final primary = await _fetchOsrm(
      baseUrl: _primaryOsrm,
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );
    if (primary != null) return primary;

    if (_primaryOsrm != _publicOsrm) {
      final fallback = await _fetchOsrm(
        baseUrl: _publicOsrm,
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
      );
      if (fallback != null) return fallback;
    }

    LocationLogger.osrm(
      'All OSRM servers failed',
      pickupLat: startLat,
      pickupLng: startLng,
      dropLat: endLat,
      dropLng: endLng,
    );
    return null;
  }

  Future<List<LatLng>> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final result = await getRouteWithMetrics(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );
    return result?.points ?? <LatLng>[];
  }

  Future<RouteResult?> _fetchOsrm({
    required String baseUrl,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final coords = '$startLng,$startLat;$endLng,$endLat';
    final url = Uri.parse(
      '$baseUrl/route/v1/driving/$coords?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['code'] != 'Ok') return null;

      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) return null;

      final route = routes.first;
      if (route is! Map) return null;

      final geometry = route['geometry'];
      final coordsList = (geometry is Map) ? geometry['coordinates'] : null;
      if (coordsList is! List || coordsList.isEmpty) return null;

      final points = <LatLng>[];
      for (final c in coordsList) {
        if (c is List && c.length >= 2) {
          points.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
        }
      }
      if (points.length < 2) return null;

      final distanceM = (route['distance'] as num?)?.toDouble() ?? 0;
      final durationS = (route['duration'] as num?)?.toDouble() ?? 0;
      if (distanceM <= 0 || durationS <= 0) return null;

      final result = RouteResult(
        points: points,
        distanceKm: double.parse((distanceM / 1000).toStringAsFixed(2)),
        durationMin: double.parse((durationS / 60).toStringAsFixed(1)),
      );
      LocationLogger.osrm(
        'Route OK via $baseUrl',
        pickupLat: startLat,
        pickupLng: startLng,
        dropLat: endLat,
        dropLng: endLng,
        distanceKm: result.distanceKm,
        durationMin: result.durationMin,
        pointCount: points.length,
      );
      return result;
    } catch (e) {
      LocationLogger.error('OSRM $baseUrl', e);
      return null;
    }
  }
}
