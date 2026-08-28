import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/chennai_area.dart';
import '../utils/location_logger.dart';

class PlaceSuggestion {
  final String displayName;
  final double lat;
  final double lon;

  const PlaceSuggestion({
    required this.displayName,
    required this.lat,
    required this.lon,
  });
}

class NominatimLocationService {
  static const Map<String, String> _headers = {
    'User-Agent': 'taxi_app',
  };

  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return [];

    final q = trimmed.toLowerCase().contains('tamil nadu')
        ? trimmed
        : '$trimmed, Tamil Nadu';
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeQueryComponent(q)}'
      '&format=json&addressdetails=1&limit=8'
      '&countrycodes=in'
      '&viewbox=76.0,13.9,80.45,8.0'
      '&bounded=1',
    );

    final response = await http.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch locations');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];

    return decoded
        .map<PlaceSuggestion>((item) {
          final map = item is Map<String, dynamic> ? item : <String, dynamic>{};
          return PlaceSuggestion(
            displayName: (map['display_name'] ?? '').toString(),
            lat: double.tryParse((map['lat'] ?? '0').toString()) ?? 0,
            lon: double.tryParse((map['lon'] ?? '0').toString()) ?? 0,
          );
        })
        .where((e) =>
            e.displayName.isNotEmpty &&
            ChennaiArea.contains(e.lat, e.lon))
        .toList();
  }

  Future<String?> reverseGeocode(double lat, double lng) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=${lat.toStringAsFixed(6)}&lon=${lng.toStringAsFixed(6)}'
      '&format=json&addressdetails=1&zoom=18',
    );

    final response = await http
        .get(url, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to reverse geocode');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final formatted = _formatAddress(decoded);
      if (formatted != null && formatted.isNotEmpty) {
        LocationLogger.geocode('reverse OK', lat: lat, lng: lng, address: formatted);
        return formatted;
      }
      final display = decoded['display_name']?.toString().trim();
      if (display != null && display.isNotEmpty) {
        LocationLogger.geocode('reverse display_name', lat: lat, lng: lng, address: display);
        return display;
      }
    }
    LocationLogger.geocode('reverse failed', lat: lat, lng: lng);
    return null;
  }

  String? _formatAddress(Map<String, dynamic> data) {
    final addr = data['address'];
    if (addr is! Map) return null;

    final parts = <String>[];
    void add(String key) {
      final value = addr[key]?.toString().trim();
      if (value == null || value.isEmpty) return;
      if (!parts.contains(value)) parts.add(value);
    }

    add('house_number');
    add('road');
    add('neighbourhood');
    add('suburb');
    add('city_district');
    add('city');
    add('town');
    add('village');
    add('state');
    add('postcode');
    add('country');

    if (parts.isEmpty) return null;
    return parts.join(', ');
  }
}
