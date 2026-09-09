import 'dart:convert';
import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';

/// Local driver session (Hive). Namespaced box — independent of customer app.
class DriverSessionStore {
  static const _boxName = 'driver_session_v1';
  static const _legacyBoxName = 'driver_session_box';

  static const keyToken = 'access_token';
  static const keyRefreshToken = 'refresh_token';
  static const keyDriverId = 'driver_id';
  static const keyEmail = 'email';
  static const keyName = 'name';
  static const keyPhone = 'phone';
  static const keyIsLoggedIn = 'is_logged_in';
  static const keyWasOnDuty = 'was_on_duty';
  static const keyLoginAt = 'login_at';
  static const keyLastActiveAt = 'last_active_at';
  static const keyDeviceId = 'device_id';
  static const keyProfileJson = 'profile_json';

  static Future<Box<dynamic>> _box() async {
    final box = await Hive.openBox(_boxName);
    if (box.isEmpty && await Hive.boxExists(_legacyBoxName)) {
      try {
        final legacy = await Hive.openBox(_legacyBoxName);
        for (final key in legacy.keys) {
          await box.put(key, legacy.get(key));
        }
      } catch (_) {}
    }
    return box;
  }

  static Future<String> deviceId() async {
    final box = await _box();
    var id = box.get(keyDeviceId) as String?;
    if (id == null || id.isEmpty) {
      final rnd = Random().nextInt(999999);
      id = 'drv-${DateTime.now().millisecondsSinceEpoch}-$rnd';
      await box.put(keyDeviceId, id);
    }
    return id;
  }

  static Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    String? driverId,
    String? email,
    String? name,
    String? phone,
    Map<String, dynamic>? profile,
    bool? wasOnDuty,
  }) async {
    final box = await _box();
    final now = DateTime.now().toIso8601String();
    await box.put(keyToken, accessToken);
    if (refreshToken != null) await box.put(keyRefreshToken, refreshToken);
    if (driverId != null) await box.put(keyDriverId, driverId);
    if (email != null) await box.put(keyEmail, email);
    if (name != null) await box.put(keyName, name);
    if (phone != null) await box.put(keyPhone, phone);
    await box.put(keyIsLoggedIn, true);
    await box.put(keyLoginAt, box.get(keyLoginAt) ?? now);
    await box.put(keyLastActiveAt, now);
    if (profile != null) {
      await box.put(keyProfileJson, jsonEncode(profile));
    }
    if (wasOnDuty != null) await box.put(keyWasOnDuty, wasOnDuty);
  }

  static Future<Map<String, dynamic>?> loadSession() async {
    final box = await _box();
    if (box.get(keyIsLoggedIn) != true) return null;
    final token = box.get(keyToken) as String?;
    if (token == null || token.isEmpty) return null;

    Map<String, dynamic>? profile;
    final profileRaw = box.get(keyProfileJson) as String?;
    if (profileRaw != null) {
      try {
        final decoded = jsonDecode(profileRaw);
        if (decoded is Map) profile = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    return {
      'token': token,
      'refreshToken': box.get(keyRefreshToken) as String?,
      'driverId': box.get(keyDriverId) as String?,
      'email': box.get(keyEmail) as String?,
      'name': box.get(keyName) as String?,
      'phone': box.get(keyPhone) as String?,
      'wasOnDuty': box.get(keyWasOnDuty) == true,
      'loginAt': box.get(keyLoginAt) as String?,
      'lastActiveAt': box.get(keyLastActiveAt) as String?,
      'deviceId': box.get(keyDeviceId) as String?,
      'profile': profile,
    };
  }

  static Future<void> touchLastActive() async {
    final box = await _box();
    if (box.get(keyIsLoggedIn) == true) {
      await box.put(keyLastActiveAt, DateTime.now().toIso8601String());
    }
  }

  static Future<void> setWasOnDuty(bool value) async {
    final box = await _box();
    await box.put(keyWasOnDuty, value);
    await touchLastActive();
  }

  static Future<bool> wasOnDuty() async {
    final box = await _box();
    return box.get(keyWasOnDuty) == true;
  }

  static Future<void> clear() async {
    final box = await _box();
    final device = box.get(keyDeviceId);
    await box.clear();
    if (device != null) await box.put(keyDeviceId, device);
  }
}
