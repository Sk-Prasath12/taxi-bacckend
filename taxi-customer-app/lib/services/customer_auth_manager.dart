import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../config/env_config.dart';
import '../domain/app_user.dart';
import '../domain/services/auth_storage.dart';
import '../utils/jwt_utils.dart';
import 'active_ride_store.dart';
import 'auth_service.dart';
import 'customer_session_store.dart';
import 'session_service.dart';

/// Validates, refreshes, and clears customer auth sessions.
class CustomerAuthManager {
  static bool _bootstrapping = false;
  static const Duration _apiTimeout = Duration(seconds: 12);

  static Future<Map<String, dynamic>?> _loadSessionOrMigrate() async {
    var session = await CustomerSessionStore.loadSession();
    if (session != null) return session;

    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;

    await CustomerSessionStore.saveSession(
      accessToken: token,
      refreshToken: await AuthStorage.getRefreshToken(),
      customerId: await AuthStorage.getCustomerId(),
      email: await AuthStorage.getUserEmail(),
      name: await AuthStorage.getUserName(),
      phone: await AuthStorage.getUserPhone(),
      profile: await AuthStorage.getProfileJson(),
    );
    return CustomerSessionStore.loadSession();
  }

  static Future<bool> bootstrapSession() async {
    if (_bootstrapping) return await isAuthenticated();
    _bootstrapping = true;
    try {
      final session = await _loadSessionOrMigrate();
      if (session == null) return false;

      var token = session['token'] as String?;
      var refresh = session['refreshToken'] as String?;
      if (token == null || token.isEmpty) return false;

      final role = parseJwtClaims(token)?.role?.toUpperCase();
      if (role != null &&
          role.isNotEmpty &&
          role != 'CUSTOMER' &&
          role != 'USER') {
        // Wrong-role token for this APK — clear only THIS app's storage.
        // Never affects the driver APK on the same device.
        await logout();
        return false;
      }

      await CustomerSessionStore.deviceId();

      if (isJwtExpired(token)) {
        if (refresh != null && refresh.isNotEmpty) {
          final refreshed = await refreshAccessToken(refreshToken: refresh);
          if (refreshed) {
            token = await CustomerSessionStore.getAccessToken() ?? token;
          } else {
            // Keep local session; user stays logged in offline until explicit logout.
            await _restoreCachedSession(token: token, refresh: refresh);
            return true;
          }
        } else {
          await _restoreCachedSession(token: token, refresh: refresh);
          return true;
        }
      }

      final fetch = await _fetchProfileDetailed(token);
      if (fetch.profile != null) {
        if (fetch.profile!['is_blocked'] == true) {
          await logout();
          return false;
        }
        await _applyProfile(fetch.profile!, token: token);
      } else if (fetch.unauthorized) {
        if (refresh != null &&
            refresh.isNotEmpty &&
            await refreshAccessToken(refreshToken: refresh)) {
          final retryToken = await CustomerSessionStore.getAccessToken();
          if (retryToken != null) {
            final retry = await _fetchProfileDetailed(retryToken);
            if (retry.profile != null) {
              if (retry.profile!['is_blocked'] == true) {
                await logout();
                return false;
              }
              await _applyProfile(retry.profile!, token: retryToken);
            } else {
              await _restoreCachedSession(token: retryToken, refresh: refresh);
            }
          } else {
            await _restoreCachedSession(token: token, refresh: refresh);
          }
        } else {
          // Keep session — do not auto-logout when driver app is also in use.
          await _restoreCachedSession(token: token, refresh: refresh);
        }
      } else {
        await _restoreCachedSession(token: token, refresh: refresh);
      }

      await CustomerSessionStore.touchLastActive();
      return true;
    } finally {
      _bootstrapping = false;
    }
  }

  static Future<void> _restoreCachedSession({
    required String token,
    String? refresh,
  }) async {
    await AuthStorage.saveTokens(token, refresh);
    await AuthService.saveToken(token);
    await restoreUserFromStorage();
  }

  static Future<bool> isAuthenticated() async {
    final session = await CustomerSessionStore.loadSession();
    final token = session?['token'] as String?;
    if (token != null && token.isNotEmpty) return true;
    final legacy = await AuthStorage.getAccessToken();
    return legacy != null && legacy.isNotEmpty;
  }

  static Future<void> persistLogin({
    required String accessToken,
    String? refreshToken,
    String? email,
    String? name,
    String? phone,
    Map<String, dynamic>? user,
  }) async {
    final customerId = user?['id']?.toString() ?? userIdFromJwt(accessToken);
    final resolvedEmail = email ?? user?['email']?.toString() ?? '';
    final resolvedName = name ?? user?['name']?.toString() ?? 'Taxi User';
    final resolvedPhone = phone ?? user?['phone']?.toString() ?? '';

    final profile = user != null
        ? Map<String, dynamic>.from(user)
        : <String, dynamic>{
            'id': customerId,
            'email': resolvedEmail,
            'name': resolvedName,
            'phone': resolvedPhone,
            'role': 'customer',
          };

    await CustomerSessionStore.saveSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      customerId: customerId,
      email: resolvedEmail,
      name: resolvedName,
      phone: resolvedPhone.isNotEmpty ? resolvedPhone : null,
      profile: profile,
    );
    await AuthStorage.saveTokens(accessToken, refreshToken);
    await AuthStorage.saveUserData(
      resolvedName,
      resolvedEmail,
      phone: resolvedPhone.isNotEmpty ? resolvedPhone : null,
      customerId: customerId,
    );
    await AuthStorage.saveProfileJson(profile);
    AppUser.applyFromMap(profile);
    await AuthService.saveToken(accessToken);
  }

  /// Saves profile fields locally and updates in-memory user state.
  static Future<void> syncProfileMap(Map<String, dynamic> profile) async {
    final token = await CustomerSessionStore.getAccessToken();
    if (token == null || token.isEmpty) return;

    await CustomerSessionStore.saveSession(
      accessToken: token,
      refreshToken: await CustomerSessionStore.getRefreshToken(),
      customerId: profile['id']?.toString(),
      email: profile['email']?.toString(),
      name: profile['name']?.toString(),
      phone: profile['phone']?.toString(),
      profile: profile,
    );

    final name = profile['name']?.toString() ?? 'Taxi User';
    final email = profile['email']?.toString() ?? '';
    await AuthStorage.saveUserData(
      name,
      email,
      phone: profile['phone']?.toString(),
      customerId: profile['id']?.toString(),
    );
    await AuthStorage.saveProfileJson(profile);
    AppUser.applyFromMap(profile);
  }

  static Future<void> restoreUserFromStorage() async {
    final session = await CustomerSessionStore.loadSession();
    if (session != null) {
      AppUser.displayName = session['name']?.toString() ?? AppUser.displayName;
      AppUser.email = session['email']?.toString() ?? AppUser.email;
      AppUser.phoneNumber = session['phone']?.toString() ?? AppUser.phoneNumber;
      AppUser.customerId = session['customerId']?.toString() ?? AppUser.customerId;
      final profile = session['profile'];
      if (profile is Map<String, dynamic>) {
        AppUser.applyFromMap(profile);
      }
      return;
    }

    final cached = await AuthStorage.getProfileJson();
    if (cached != null) AppUser.applyFromMap(cached);

    final name = await AuthStorage.getUserName();
    final email = await AuthStorage.getUserEmail();
    final phone = await AuthStorage.getUserPhone();
    final id = await AuthStorage.getCustomerId();
    if (name != null) AppUser.displayName = name;
    if (email != null) AppUser.email = email;
    if (phone != null) AppUser.phoneNumber = phone;
    if (id != null) AppUser.customerId = id;
  }

  static Future<bool> refreshAccessToken({String? refreshToken}) async {
    refreshToken ??= await CustomerSessionStore.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final url = Uri.parse('${ApiConfig.authBase}/refresh');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(_apiTimeout);
      if (response.statusCode != 200 && response.statusCode != 201) {
        return false;
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return false;

      String? access;
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        access = data['accessToken']?.toString() ??
            data['token']?.toString() ??
            data['access_token']?.toString();
      }
      access ??= body['accessToken']?.toString() ??
          body['token']?.toString() ??
          body['access_token']?.toString();
      if (access == null || access.isEmpty) return false;

      final session = await CustomerSessionStore.loadSession();
      await CustomerSessionStore.saveSession(
        accessToken: access,
        refreshToken: refreshToken,
        customerId: session?['customerId'] as String?,
        email: session?['email'] as String?,
        name: session?['name'] as String?,
        phone: session?['phone'] as String?,
        profile: session?['profile'] as Map<String, dynamic>?,
      );
      await AuthStorage.saveTokens(access, refreshToken);
      await AuthService.saveToken(access);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('CustomerAuthManager.refreshAccessToken: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    await ActiveRideStore.clear();
    await SessionService.clearRide();
    await AuthStorage.clear();
    await CustomerSessionStore.clear();
    AppUser.reset();
  }

  static Future<({Map<String, dynamic>? profile, bool unauthorized})>
      _fetchProfileDetailed(String token) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/customers/profile');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_apiTimeout);
      if (response.statusCode == 401) {
        return (profile: null, unauthorized: true);
      }
      if (response.statusCode != 200) {
        return (profile: null, unauthorized: false);
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        return (profile: null, unauthorized: false);
      }
      final user = data['user'];
      if (user is Map<String, dynamic>) {
        return (profile: user, unauthorized: false);
      }
      return (profile: data, unauthorized: false);
    } catch (_) {
      return (profile: null, unauthorized: false);
    }
  }

  static Future<void> _applyProfile(
    Map<String, dynamic> profile, {
    required String token,
  }) async {
    final blocked = profile['is_blocked'] == true;
    if (blocked) {
      await logout();
      return;
    }

    await CustomerSessionStore.saveSession(
      accessToken: token,
      refreshToken: await CustomerSessionStore.getRefreshToken(),
      customerId: profile['id']?.toString(),
      email: profile['email']?.toString(),
      name: profile['name']?.toString(),
      phone: profile['phone']?.toString(),
      profile: profile,
    );
    await syncProfileMap(profile);
  }
}
