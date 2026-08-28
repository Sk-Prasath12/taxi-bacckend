import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Stores access token for API and WebSocket. Connect SocketService after saving.
class AuthStorage {
  static const _keyAccessToken = 'access_token';
  static const _keyToken = 'token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserName = 'user_name';
  static const _keyUserEmail = 'user_email';
  static const _keyUserPhone = 'user_phone';
  static const _keyCustomerId = 'customer_id';
  static const _keyProfileJson = 'user_profile_json';
  static const _keyLocalHistory = 'local_ride_history';
  static const _keyLocalStats = 'local_ride_stats';

  static Future<void> saveTokens(String accessToken, [String? refreshToken]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyToken, accessToken);
    if (refreshToken != null) await prefs.setString(_keyRefreshToken, refreshToken);
  }

  static Future<void> saveUserData(String name, String email, {String? phone, String? customerId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email);
    if (phone != null) await prefs.setString(_keyUserPhone, phone);
    if (customerId != null) await prefs.setString(_keyCustomerId, customerId);
  }

  static Future<void> saveProfileJson(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfileJson, jsonEncode(profile));
  }

  static Future<Map<String, dynamic>?> getProfileJson() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyProfileJson);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  static Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserPhone);
  }

  static Future<String?> getCustomerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCustomerId);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken) ?? prefs.getString(_keyToken);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  // Local History Management
  static Future<void> addRideToHistory(Map<String, dynamic> rideData) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_keyLocalHistory) ?? [];
    history.insert(0, jsonEncode(rideData));
    await prefs.setStringList(_keyLocalHistory, history);
    
    // Update local stats
    final statsJson = prefs.getString(_keyLocalStats);
    Map<String, dynamic> stats = statsJson != null ? jsonDecode(statsJson) : {
      'totalRideCount': 0,
      'totalSpent': 0,
      'totalDistanceKm': 0.0,
    };
    
    stats['totalRideCount'] = (stats['totalRideCount'] ?? 0) + 1;
    final amount = double.tryParse(rideData['totalAmount']?.toString().replaceAll('₹', '') ?? '0') ?? 0.0;
    stats['totalSpent'] = (stats['totalSpent'] ?? 0) + amount.toInt();
    final distStr = rideData['distance']?.toString().replaceAll(' km', '') ?? '0.0';
    stats['totalDistanceKm'] = (stats['totalDistanceKm'] ?? 0.0) + (double.tryParse(distStr) ?? 0.0);
    
    await prefs.setString(_keyLocalStats, jsonEncode(stats));
  }

  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_keyLocalHistory) ?? [];
    return history.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  static Future<Map<String, dynamic>> getLocalStats() async {
    final prefs = await SharedPreferences.getInstance();
    final statsJson = prefs.getString(_keyLocalStats);
    return statsJson != null ? jsonDecode(statsJson) : {
      'totalRideCount': 42,
      'totalSpent': 528,
      'totalDistanceKm': 156.5,
    };
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserPhone);
    await prefs.remove(_keyCustomerId);
    await prefs.remove(_keyProfileJson);
    await prefs.remove(_keyLocalHistory);
    await prefs.remove(_keyLocalStats);
  }
}
