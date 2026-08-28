import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists pickup/drop draft between screens and app restarts.
class BookingDraftStore {
  static const _key = 'booking_draft_json';

  /// Persist full or partial booking draft (pickup and/or drop).
  static Future<void> save({
    double? pickupLat,
    double? pickupLng,
    String? pickupAddress,
    double? dropLat,
    double? dropLng,
    String? dropAddress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await load() ?? <String, dynamic>{};
    final next = <String, dynamic>{
      ...existing,
      if (pickupLat != null) 'pickupLat': pickupLat,
      if (pickupLng != null) 'pickupLng': pickupLng,
      if (pickupAddress != null) 'pickupAddress': pickupAddress,
      if (dropLat != null) 'dropLat': dropLat,
      if (dropLng != null) 'dropLng': dropLng,
      if (dropAddress != null) 'dropAddress': dropAddress,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_key, jsonEncode(next));
  }

  static Future<void> savePickup({
    required double lat,
    required double lng,
    required String address,
  }) =>
      save(pickupLat: lat, pickupLng: lng, pickupAddress: address);

  static Future<void> saveDrop({
    required double lat,
    required double lng,
    required String address,
  }) =>
      save(dropLat: lat, dropLng: lng, dropAddress: address);

  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
