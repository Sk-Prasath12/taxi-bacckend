import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../api/api_constants.dart';
import '../utils/navigation_logger.dart';
import '../utils/ride_navigation_utils.dart';

class OsrmNavStep {
  final LatLng location;
  final String instruction;
  final double distanceMeters;
  final String? roadName;
  final String maneuverType;
  final String maneuverModifier;

  const OsrmNavStep({
    required this.location,
    required this.instruction,
    required this.distanceMeters,
    this.roadName,
    this.maneuverType = '',
    this.maneuverModifier = '',
  });

  IconData get icon {
    switch (maneuverModifier) {
      case 'left':
      case 'slight left':
      case 'sharp left':
        return Icons.turn_left;
      case 'right':
      case 'slight right':
      case 'sharp right':
        return Icons.turn_right;
      case 'uturn':
        return Icons.u_turn_left;
      case 'straight':
        return Icons.straight;
      default:
        if (maneuverType == 'arrive') return Icons.flag;
        if (maneuverType == 'depart') return Icons.navigation;
        return Icons.arrow_upward;
    }
  }
}

class OsrmRouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<OsrmNavStep> steps;

  const OsrmRouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.steps = const [],
  });

  double get distanceKm => distanceMeters / 1000;
  double get durationMin => durationSeconds / 60;
}

class OsrmService {
  static const _publicOsrm = 'https://router.project-osrm.org';

  String get _primaryOsrm => ApiConstants.osrmUrl.replaceAll(RegExp(r'/$'), '');

  Future<OsrmRouteResult?> getRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    if (!RideNavigationUtils.isValidCoord(from.latitude, from.longitude) ||
        !RideNavigationUtils.isValidCoord(to.latitude, to.longitude)) {
      NavigationLogger.error('OSRM', 'Invalid coordinates from=$from to=$to');
      return null;
    }

    final primary = await _fetch(baseUrl: _primaryOsrm, from: from, to: to);
    if (primary != null) return primary;

    if (_primaryOsrm != _publicOsrm) {
      NavigationLogger.route('Primary OSRM failed, trying public fallback');
      return _fetch(baseUrl: _publicOsrm, from: from, to: to);
    }
    return null;
  }

  Future<OsrmRouteResult?> _fetch({
    required String baseUrl,
    required LatLng from,
    required LatLng to,
  }) async {
    final coords =
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    final url = Uri.parse(
      '$baseUrl/route/v1/driving/$coords?overview=full&geometries=geojson&steps=true',
    );

    NavigationLogger.osrm(
      'Request',
      fromLat: from.latitude,
      fromLng: from.longitude,
      toLat: to.latitude,
      toLng: to.longitude,
      server: baseUrl,
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        NavigationLogger.error('OSRM HTTP ${response.statusCode}', response.body);
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['code'] != 'Ok') {
        NavigationLogger.error('OSRM code', decoded['code']);
        return null;
      }

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
          final lng = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          if (RideNavigationUtils.isValidCoord(lat, lng)) {
            points.add(LatLng(lat, lng));
          }
        }
      }
      if (points.length < 2) {
        NavigationLogger.error('OSRM', 'Too few route points: ${points.length}');
        return null;
      }

      final distanceM = (route['distance'] as num?)?.toDouble() ?? 0;
      final durationS = (route['duration'] as num?)?.toDouble() ?? 0;
      if (distanceM <= 0 || durationS <= 0) return null;

      final steps = _parseSteps(route);

      final result = OsrmRouteResult(
        points: points,
        distanceMeters: distanceM,
        durationSeconds: durationS,
        steps: steps,
      );

      NavigationLogger.osrm(
        'Route OK',
        fromLat: from.latitude,
        fromLng: from.longitude,
        toLat: to.latitude,
        toLng: to.longitude,
        distanceKm: result.distanceKm,
        durationMin: result.durationMin,
        pointCount: points.length,
        server: baseUrl,
      );
      return result;
    } catch (e) {
      NavigationLogger.error('OSRM fetch $baseUrl', e);
      return null;
    }
  }

  List<OsrmNavStep> _parseSteps(Map route) {
    final legs = route['legs'];
    if (legs is! List || legs.isEmpty) return const [];

    final leg = legs.first;
    if (leg is! Map) return const [];

    final rawSteps = leg['steps'];
    if (rawSteps is! List) return const [];

    final steps = <OsrmNavStep>[];
    for (final raw in rawSteps) {
      if (raw is! Map) continue;
      final maneuver = raw['maneuver'];
      if (maneuver is! Map) continue;

      final loc = maneuver['location'];
      if (loc is! List || loc.length < 2) continue;

      final lng = (loc[0] as num).toDouble();
      final lat = (loc[1] as num).toDouble();
      if (!RideNavigationUtils.isValidCoord(lat, lng)) continue;

      final type = maneuver['type']?.toString() ?? '';
      final modifier = maneuver['modifier']?.toString() ?? '';
      final name = raw['name']?.toString();
      final dist = (raw['distance'] as num?)?.toDouble() ?? 0;

      steps.add(
        OsrmNavStep(
          location: LatLng(lat, lng),
          instruction: _formatInstruction(type, modifier, name),
          distanceMeters: dist,
          roadName: name,
          maneuverType: type,
          maneuverModifier: modifier,
        ),
      );
    }
    return steps;
  }

  static String _formatInstruction(String type, String modifier, String? name) {
    final road = (name != null && name.isNotEmpty) ? ' onto $name' : '';

    switch (type) {
      case 'depart':
        final dir = modifier.isNotEmpty && modifier != 'straight' ? '$modifier ' : '';
        return 'Head $dir$road'.trim();
      case 'arrive':
        return 'You have arrived at destination';
      case 'turn':
      case 'fork':
      case 'merge':
      case 'on ramp':
      case 'off ramp':
      case 'roundabout':
      case 'rotary':
      case 'end of road':
        return '${_modifierPhrase(modifier)}$road';
      case 'continue':
        return 'Continue straight$road';
      default:
        if (modifier.isNotEmpty) return '${_modifierPhrase(modifier)}$road';
        return 'Continue$road';
    }
  }

  static String _modifierPhrase(String modifier) {
    switch (modifier) {
      case 'left':
        return 'Turn left';
      case 'right':
        return 'Turn right';
      case 'slight left':
        return 'Turn slight left';
      case 'slight right':
        return 'Turn slight right';
      case 'sharp left':
        return 'Turn sharp left';
      case 'sharp right':
        return 'Turn sharp right';
      case 'uturn':
        return 'Make a U-turn';
      case 'straight':
        return 'Continue straight';
      default:
        return 'Continue';
    }
  }
}
