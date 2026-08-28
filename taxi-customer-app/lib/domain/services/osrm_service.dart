import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../config/env_config.dart';

class OsrmService {
  final String baseUrl;

  OsrmService({String? baseUrl})
      : baseUrl = (baseUrl ?? EnvConfig.osrmBaseUrl).isNotEmpty
            ? (baseUrl ?? EnvConfig.osrmBaseUrl)
            : 'https://router.project-osrm.org';

  Future<OsrmRouteResult?> getRoute(
    double startLng,
    double startLat,
    double endLng,
    double endLat,
  ) async {
    final results = await getRouteAlternatives(
      startLng, startLat, endLng, endLat,
      maxAlternatives: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  static const _publicOsrmUrl = 'https://router.project-osrm.org';

  /// Fetches up to [maxAlternatives] + 1 routes (primary + alternatives), max 3 total.
  /// Tries local OSRM first, then public OSRM; if both fail, returns a straight-line fallback so a route always appears.
  Future<List<OsrmRouteResult>> getRouteAlternatives(
    double startLng,
    double startLat,
    double endLng,
    double endLat, {
    int maxAlternatives = 2,
  }) async {
    final results = await _fetchFromServer(
      baseUrl: baseUrl,
      startLng: startLng,
      startLat: startLat,
      endLng: endLng,
      endLat: endLat,
      maxAlternatives: maxAlternatives,
    );
    if (results.isNotEmpty) return results;

    if (baseUrl != _publicOsrmUrl) {
      final publicResults = await _fetchFromServer(
        baseUrl: _publicOsrmUrl,
        startLng: startLng,
        startLat: startLat,
        endLng: endLng,
        endLat: endLat,
        maxAlternatives: maxAlternatives,
      );
      if (publicResults.isNotEmpty) return publicResults;
    }

    return _fallbackRoute(startLng, startLat, endLng, endLat);
  }

  Future<List<OsrmRouteResult>> _fetchFromServer({
    required String baseUrl,
    required double startLng,
    required double startLat,
    required double endLng,
    required double endLat,
    required int maxAlternatives,
  }) async {
    final coords = '$startLng,$startLat;$endLng,$endLat';
    final url = Uri.parse(
      '$baseUrl/route/v1/driving/$coords?overview=full&geometries=geojson&alternatives=true&steps=true',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final routes = data['routes'] as List?;
      if (data['code'] != 'Ok' || routes == null || routes.isEmpty) return [];

      final results = <OsrmRouteResult>[];
      final maxRoutes = (maxAlternatives + 1).clamp(1, 3);
      for (var i = 0; i < routes.length && i < maxRoutes; i++) {
        final route = routes[i];
        final coordsList = route['geometry']?['coordinates'] as List?;
        if (coordsList == null || coordsList.isEmpty) continue;

        final routePoints = coordsList
            .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
            .toList();
        final distanceKm = (route['distance'] ?? 0) / 1000;
        final durationSeconds = (route['duration'] ?? 0).toDouble();
        final summary = _buildRouteSummary(route, i + 1, distanceKm, durationSeconds);

        results.add(OsrmRouteResult(
          routePoints: routePoints,
          distanceKm: distanceKm,
          durationSeconds: durationSeconds,
          summary: summary,
        ));
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  /// Builds a readable summary from route legs/steps (e.g. "Mayiladuthurai - Komal Road - Komal").
  String _buildRouteSummary(
    Map<String, dynamic> route,
    int routeIndex,
    double distanceKm,
    double durationSeconds,
  ) {
    final names = <String>[];
    final legs = route['legs'] as List?;
    if (legs != null) {
      for (final leg in legs) {
        final steps = leg['steps'] as List?;
        if (steps != null) {
          for (final step in steps) {
            final name = step['name']?.toString().trim();
            if (name != null && name.isNotEmpty && (names.isEmpty || names.last != name)) {
              names.add(name);
            }
          }
        }
      }
    }
    if (names.isNotEmpty) {
      return names.join(' - ');
    }
    final mins = (durationSeconds / 60).round();
    return 'Route $routeIndex • ${distanceKm.toStringAsFixed(1)} km • $mins min';
  }

  /// Fallback: single straight-line route so the path always appears on the map.
  List<OsrmRouteResult> _fallbackRoute(
    double startLng,
    double startLat,
    double endLng,
    double endLat,
  ) {
    final points = [
      LatLng(startLat, startLng),
      LatLng(endLat, endLng),
    ];
    return [
      OsrmRouteResult(
        routePoints: points,
        distanceKm: 0,
        durationSeconds: 0,
        summary: 'Direct route',
      ),
    ];
  }

  Future<List<LocationSuggestion>> searchLocation(String query) async {
    if (query.length < 3) return [];

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5',
    );

    try {
      final response = await http
          .get(url, headers: {'User-Agent': 'com.manimaran.taxi_user'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => LocationSuggestion.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Reverse geocode: get address from map (lat/lon) via Nominatim.
  /// Returns full display_name or null on failure.
  Future<String?> reverseGeocode(double lat, double lon) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?lat=${lat.toStringAsFixed(6)}&lon=${lon.toStringAsFixed(6)}&format=json',
    );
    try {
      final response = await http
          .get(url, headers: {'User-Agent': 'com.manimaran.taxi_user'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>?;
      final name = data?['display_name'] as String?;
      return name?.trim().isNotEmpty == true ? name : null;
    } catch (e) {
      return null;
    }
  }
}

class LocationSuggestion {
  final String title;
  final String subtitle;
  final double lat;
  final double lon;

  LocationSuggestion({
    required this.title,
    required this.subtitle,
    required this.lat,
    required this.lon,
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      title: json['display_name'].split(',')[0],
      subtitle: json['display_name'].split(',').skip(1).join(',').trim(),
      lat: double.parse(json['lat']),
      lon: double.parse(json['lon']),
    );
  }
}

class OsrmRouteResult {
  final List<LatLng> routePoints;
  final double distanceKm;
  final double durationSeconds;
  /// Human-readable summary (e.g. "Mayiladuthurai - Komal Road - Komal").
  final String summary;

  OsrmRouteResult({
    required this.routePoints,
    required this.distanceKm,
    required this.durationSeconds,
    this.summary = '',
  });
}

