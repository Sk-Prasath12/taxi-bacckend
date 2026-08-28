import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local cache of in-progress ride for app-restart recovery.
class ActiveRideStore {
  static const _keyRideId = 'customer_active_ride_id';
  static const _keyPayload = 'customer_active_ride_payload';
  static const _keyStatus = 'customer_active_ride_status';

  static Future<void> save({
    required String rideId,
    required Map<String, dynamic> payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRideId, rideId);
    await prefs.setString(_keyPayload, jsonEncode(payload));
    await prefs.setString(
      _keyStatus,
      (payload['status'] ?? '').toString(),
    );
  }

  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rideId = prefs.getString(_keyRideId);
    final raw = prefs.getString(_keyPayload);
    if (rideId == null || rideId.isEmpty || raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return {
        'ride_id': rideId,
        ...Map<String, dynamic>.from(decoded),
      };
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRideId);
    await prefs.remove(_keyPayload);
    await prefs.remove(_keyStatus);
  }
}
