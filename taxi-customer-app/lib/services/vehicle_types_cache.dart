import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ride_models.dart';

/// Caches vehicle types so booking works after one successful API load.
/// Bump key whenever the canonical catalog changes.
class VehicleTypesCache {
  static const _key = 'vehicle_types_cache_v3';
  static const _legacyKeys = ['vehicle_types_cache_v2', 'vehicle_types_cache_v1'];

  static Future<void> save(List<VehicleTypeModel> vehicles) async {
    if (vehicles.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    for (final legacy in _legacyKeys) {
      await prefs.remove(legacy);
    }
    final payload = vehicles
        .map((v) => {
              'id': v.id,
              'name': v.name,
              'code': v.code,
              'max_passengers': v.maxPassengers,
              'per_km_rate': v.perKmRate,
            })
        .toList();
    await prefs.setString(_key, jsonEncode(payload));
  }

  static Future<List<VehicleTypeModel>> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final legacy in _legacyKeys) {
      await prefs.remove(legacy);
    }
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => VehicleTypeModel.fromJson(Map<String, dynamic>.from(e)))
          .where((v) => v.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    for (final legacy in _legacyKeys) {
      await prefs.remove(legacy);
    }
  }
}
