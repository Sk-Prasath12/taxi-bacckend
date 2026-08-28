import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistent customer session (SharedPreferences). Cleared only on logout.
class CustomerSessionStore {
  static const _prefix = 'customer_session_';
  static const keyToken = '${_prefix}access_token';
  static const keyRefreshToken = '${_prefix}refresh_token';
  static const keyCustomerId = '${_prefix}customer_id';
  static const keyEmail = '${_prefix}email';
  static const keyName = '${_prefix}name';
  static const keyPhone = '${_prefix}phone';
  static const keyIsLoggedIn = '${_prefix}is_logged_in';
  static const keyLoginAt = '${_prefix}login_at';
  static const keyLastActiveAt = '${_prefix}last_active_at';
  static const keyDeviceId = '${_prefix}device_id';
  static const keyProfileJson = '${_prefix}profile_json';
  static const keyManuallyLoggedOut = '${_prefix}manually_logged_out';
  static const keyLastLoginEmail = '${_prefix}last_login_email';

  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(keyDeviceId);
    if (id == null || id.isEmpty) {
      final rnd = Random().nextInt(999999);
      id = 'cust-${DateTime.now().millisecondsSinceEpoch}-$rnd';
      await prefs.setString(keyDeviceId, id);
    }
    return id;
  }

  static Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    String? customerId,
    String? email,
    String? name,
    String? phone,
    Map<String, dynamic>? profile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    await prefs.setString(keyToken, accessToken);
    await prefs.setString('token', accessToken);
    await prefs.setString('access_token', accessToken);
    await prefs.setString('auth_token', accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(keyRefreshToken, refreshToken);
      await prefs.setString('refresh_token', refreshToken);
    }
    if (customerId != null) await prefs.setString(keyCustomerId, customerId);
    if (email != null) {
      await prefs.setString(keyEmail, email);
      await prefs.setString('user_email', email);
      await prefs.setString(keyLastLoginEmail, email);
    }
    if (name != null) {
      await prefs.setString(keyName, name);
      await prefs.setString('user_name', name);
    }
    if (phone != null) await prefs.setString(keyPhone, phone);
    await prefs.setBool(keyIsLoggedIn, true);
    await prefs.setBool(keyManuallyLoggedOut, false);
    await prefs.setString(keyLoginAt, prefs.getString(keyLoginAt) ?? now);
    await prefs.setString(keyLastActiveAt, now);
    if (profile != null) {
      await prefs.setString(keyProfileJson, jsonEncode(profile));
    }
  }

  static Future<Map<String, dynamic>?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(keyManuallyLoggedOut) == true) return null;
    if (prefs.getBool(keyIsLoggedIn) != true) {
      final legacyToken = prefs.getString('auth_token') ??
          prefs.getString('token') ??
          prefs.getString('access_token');
      if (legacyToken == null || legacyToken.isEmpty) return null;
      return {
        'token': legacyToken,
        'refreshToken': prefs.getString(keyRefreshToken) ??
            prefs.getString('refresh_token'),
        'customerId': prefs.getString(keyCustomerId),
        'email': prefs.getString(keyEmail) ?? prefs.getString('user_email'),
        'name': prefs.getString(keyName) ?? prefs.getString('user_name'),
        'phone': prefs.getString(keyPhone),
        'loginAt': prefs.getString(keyLoginAt),
        'lastActiveAt': prefs.getString(keyLastActiveAt),
        'deviceId': prefs.getString(keyDeviceId),
        'profile': null,
      };
    }

    final token = prefs.getString(keyToken);
    if (token == null || token.isEmpty) return null;

    Map<String, dynamic>? profile;
    final profileRaw = prefs.getString(keyProfileJson);
    if (profileRaw != null) {
      try {
        final decoded = jsonDecode(profileRaw);
        if (decoded is Map) profile = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    return {
      'token': token,
      'refreshToken': prefs.getString(keyRefreshToken),
      'customerId': prefs.getString(keyCustomerId),
      'email': prefs.getString(keyEmail),
      'name': prefs.getString(keyName),
      'phone': prefs.getString(keyPhone),
      'loginAt': prefs.getString(keyLoginAt),
      'lastActiveAt': prefs.getString(keyLastActiveAt),
      'deviceId': prefs.getString(keyDeviceId),
      'profile': profile,
    };
  }

  static Future<String?> getAccessToken() async {
    final session = await loadSession();
    return session?['token'] as String?;
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyRefreshToken) ?? prefs.getString('refresh_token');
  }

  static Future<void> touchLastActive() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(keyIsLoggedIn) == true) {
      await prefs.setString(
        keyLastActiveAt,
        DateTime.now().toIso8601String(),
      );
    }
  }

  static Future<String?> getLastLoginEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyLastLoginEmail) ??
        prefs.getString(keyEmail) ??
        prefs.getString('user_email');
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final device = prefs.getString(keyDeviceId);
    final lastEmail = prefs.getString(keyLastLoginEmail);
    await prefs.setBool(keyManuallyLoggedOut, true);
    await prefs.remove(keyToken);
    await prefs.remove(keyRefreshToken);
    await prefs.remove(keyCustomerId);
    await prefs.remove(keyEmail);
    await prefs.remove(keyName);
    await prefs.remove(keyPhone);
    await prefs.remove(keyIsLoggedIn);
    await prefs.remove(keyLoginAt);
    await prefs.remove(keyLastActiveAt);
    await prefs.remove(keyProfileJson);
    await prefs.remove('auth_token');
    await prefs.remove('token');
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    if (device != null) await prefs.setString(keyDeviceId, device);
    if (lastEmail != null && lastEmail.isNotEmpty) {
      await prefs.setString(keyLastLoginEmail, lastEmail);
    }
  }
}
