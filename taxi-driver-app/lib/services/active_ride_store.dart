import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Persists in-progress driver ride so navigation can resume after app restart.
class ActiveRideStore {
  static const _boxName = 'active_ride_box';
  static const _payloadKey = 'payload';

  static Future<Box<dynamic>> _box() => Hive.openBox(_boxName);

  static Future<void> save(Map<String, dynamic> ride) async {
    final box = await _box();
    await box.put(_payloadKey, jsonEncode(ride));
  }

  static Future<Map<String, dynamic>?> load() async {
    final box = await _box();
    final raw = box.get(_payloadKey);
    if (raw is! String || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static Future<void> clear() async {
    final box = await _box();
    await box.delete(_payloadKey);
  }

  static bool isTerminalStatus(String? status) {
    final s = (status ?? '').toUpperCase();
    return s == 'COMPLETED' || s == 'CANCELLED';
  }
}
