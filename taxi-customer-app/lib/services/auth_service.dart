import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/app_endpoints.dart';

class AuthService {
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };
  static const Duration _apiTimeout = Duration(seconds: 25);

  static Map<String, dynamic> _success([Map<String, dynamic>? data]) => {
        'success': true,
        'message': 'OK',
        'data': data ?? <String, dynamic>{},
      };

  static Map<String, dynamic>? _decodeBody(http.Response response) {
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) return raw;
    } catch (_) {}
    return null;
  }

  static Map<String, dynamic> _otpDataFromBody(Map<String, dynamic>? body) {
    if (body == null) return <String, dynamic>{};
    final otp = body['otp']?.toString().trim();
    return {
      if (otp != null && RegExp(r'^\d{6}$').hasMatch(otp)) 'otp': otp,
      if (body['email_sent'] != null) 'email_sent': body['email_sent'],
      if (body['message'] != null) 'message': body['message'].toString(),
    };
  }

  static Map<String, dynamic> _failure(String message, {int? statusCode}) => {
        'success': false,
        'message': message,
        'statusCode': statusCode,
      };

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static String? _extractToken(dynamic body) {
    if (body is! Map<String, dynamic>) return null;
    final direct = body['token'] ?? body['accessToken'];
    if (direct != null && direct.toString().isNotEmpty) {
      return direct.toString();
    }
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      final nested = data['token'] ?? data['accessToken'];
      if (nested != null && nested.toString().isNotEmpty) {
        return nested.toString();
      }
    }
    return null;
  }

  static String? _extractRefreshToken(dynamic body) {
    if (body is! Map<String, dynamic>) return null;
    final direct = body['refreshToken'] ?? body['refresh_token'];
    if (direct != null && direct.toString().isNotEmpty) {
      return direct.toString();
    }
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      final nested = data['refreshToken'] ?? data['refresh_token'];
      if (nested != null && nested.toString().isNotEmpty) {
        return nested.toString();
      }
    }
    return null;
  }

  static String _friendlyMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('customer already exists')) {
      return 'This email is already registered. Please sign in instead.';
    }
    if (lower.contains('customer access only') ||
        lower.contains('driver or admin')) {
      return 'This email is a driver/admin account. Use a new email for the customer app.';
    }
    if (lower.contains('invalid email or password')) {
      return 'Wrong email or password.';
    }
    return raw;
  }

  static bool _responseOk(http.Response response) {
    if (response.statusCode != 200 && response.statusCode != 201) {
      return false;
    }
    try {
      if (response.body.isEmpty) return true;
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['success'] == false) {
        return false;
      }
    } catch (_) {}
    return true;
  }

  static String _extractMessage(http.Response response, String fallback) {
    final raw = response.body;
    if (raw.contains('NOT_FOUND') ||
        raw.contains('<!DOCTYPE html') ||
        response.statusCode == 404) {
      return 'Server is not available. Try again in a minute.';
    }
    try {
      if (raw.isNotEmpty) {
        final body = jsonDecode(raw);
        if (body is Map<String, dynamic>) {
          final message = body['message'] ?? body['error'] ?? body['msg'];
          if (message is String && message.trim().isNotEmpty) {
            return _friendlyMessage(message.trim());
          }
        }
      }
    } catch (_) {}
    if (response.statusCode == 503) {
      return 'Database unavailable. Please try again.';
    }
    return fallback;
  }

  static String _connectionErrorMessage([Object? error]) {
    final base = ApiConfig.baseUrl;
    if (base.isEmpty || Uri.tryParse(base)?.hasAuthority != true) {
      return 'App server URL is missing. Reinstall the official release APK.';
    }
    if (AppEndpoints.isPlaceholder(base)) {
      return 'This app was not built correctly. Reinstall the official release APK.';
    }
    final raw = error?.toString().toLowerCase() ?? '';
    if (raw.contains('failed host lookup') ||
        raw.contains('no address associated') ||
        raw.contains('no host specified')) {
      return 'Server address not found. Ask admin to rebuild APK with the current server URL.';
    }
    if (raw.contains('timeoutexception') ||
        raw.contains('timed out') ||
        raw.contains('future not completed') ||
        raw.contains('connection refused') ||
        raw.contains('network is unreachable') ||
        raw.contains('socketexception')) {
      return 'Cannot reach $base. Check internet and try again.';
    }
    return 'Cannot reach server. Check internet and try again.';
  }

  static Uri? _apiUri(String path) {
    final base = ApiConfig.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return null;
    final cleanPath = path.replaceFirst(RegExp(r'^/+'), '');
    final uri = Uri.tryParse('$base/$cleanPath');
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return uri;
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    http.Client? client,
  }) async {
    final url = _apiUri('customers/register/email');
    if (url == null) return _failure(_connectionErrorMessage());

    try {
      final response = await (client ?? http.Client())
          .post(
        url,
        headers: _headers,
        body: jsonEncode({
          'name': name.trim(),
          'email': _normalizeEmail(email),
          'phone': phone.trim(),
        }),
      )
          .timeout(_apiTimeout);
      if (kDebugMode) print('register response: ${response.body}');

      if (_responseOk(response)) {
        return _success(_otpDataFromBody(_decodeBody(response)));
      }

      return _failure(
        _extractMessage(response, 'Failed to register'),
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (kDebugMode) print('register error: $e');
      return _failure(_connectionErrorMessage(e));
    }
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final url = _apiUri('customers/register/verify-otp');
    if (url == null) return _failure(_connectionErrorMessage());

    try {
      final response = await http
          .post(
        url,
        headers: _headers,
        body: jsonEncode({
          'email': _normalizeEmail(email),
          'otp': otp.trim(),
        }),
      )
          .timeout(_apiTimeout);
      if (kDebugMode) print('verifyOtp response: ${response.body}');

      if (_responseOk(response)) {
        return _success();
      }

      return _failure(
        _extractMessage(response, 'Failed to verify OTP'),
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (kDebugMode) print('verifyOtp error: $e');
      return _failure(_connectionErrorMessage(e));
    }
  }

  static Future<Map<String, dynamic>> setPassword({
    required String email,
    required String password,
    String? otp,
    http.Client? client,
  }) async {
    final url = _apiUri('customers/register/set-password');
    if (url == null) return _failure(_connectionErrorMessage());

    try {
      final response = await (client ?? http.Client())
          .post(
        url,
        headers: _headers,
        body: jsonEncode({
          'email': _normalizeEmail(email),
          'password': password,
          if (otp != null && otp.trim().isNotEmpty) 'otp': otp.trim(),
        }),
      )
          .timeout(_apiTimeout);
      if (kDebugMode) print('setPassword response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        Map<String, dynamic>? decoded;
        try {
          final raw = jsonDecode(response.body);
          if (raw is Map<String, dynamic>) decoded = raw;
        } catch (_) {}
        return _success({
          'token': _extractToken(decoded),
          'refreshToken': _extractRefreshToken(decoded),
          'user': decoded?['user'],
        });
      }

      return _failure(
        _extractMessage(response, 'Failed to set password'),
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (kDebugMode) print('setPassword error: $e');
      return _failure(_connectionErrorMessage(e));
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = _apiUri('customers/login');
    if (url == null) return _failure(_connectionErrorMessage());

    try {
      final response = await http
          .post(
        url,
        headers: _headers,
        body: jsonEncode({
          'email': _normalizeEmail(email),
          'password': password,
        }),
      )
          .timeout(_apiTimeout);
      if (kDebugMode) print('login response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        Map<String, dynamic>? decoded;
        try {
          final raw = jsonDecode(response.body);
          if (raw is Map<String, dynamic>) decoded = raw;
        } catch (_) {}
        if (decoded?['success'] == false) {
          return _failure(
            _extractMessage(response, 'Login failed'),
            statusCode: response.statusCode,
          );
        }
        final token = _extractToken(decoded);
        if (token == null || token.isEmpty) {
          return _failure('Login failed: no token from server');
        }
        return _success({
          'token': token,
          'refreshToken': _extractRefreshToken(decoded),
          'user': decoded?['user'],
        });
      }

      return _failure(
        _extractMessage(response, 'Login failed'),
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (kDebugMode) print('login error: $e');
      return _failure(_connectionErrorMessage(e));
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ??
        prefs.getString('token') ??
        prefs.getString('access_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> logout() async {
    // Use [CustomerAuthManager.logout] for full session teardown.
  }

  static Future<Map<String, dynamic>> sendForgotPasswordOtp({
    required String email,
  }) async {
    final url = _apiUri('customers/forgot-password/email');
    if (url == null) return _failure(_connectionErrorMessage());

    try {
      final response = await http
          .post(
        url,
        headers: _headers,
        body: jsonEncode({'email': _normalizeEmail(email)}),
      )
          .timeout(_apiTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _success(_otpDataFromBody(_decodeBody(response)));
      }

      return _failure(
        _extractMessage(response, 'Failed to send OTP'),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return _failure(_connectionErrorMessage(e));
    }
  }

  static Future<Map<String, dynamic>> verifyForgotPasswordOtp({
    required String email,
    required String otp,
  }) async {
    final url = _apiUri('customers/forgot-password/verify-otp');
    if (url == null) return _failure(_connectionErrorMessage());

    try {
      final response = await http
          .post(
        url,
        headers: _headers,
        body: jsonEncode({
          'email': _normalizeEmail(email),
          'otp': otp.trim(),
        }),
      )
          .timeout(_apiTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _success();
      }

      return _failure(
        _extractMessage(response, 'Failed to verify OTP'),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return _failure(_connectionErrorMessage(e));
    }
  }

  static Future<Map<String, dynamic>> setNewPassword({
    required String email,
    required String password,
  }) async {
    final url = _apiUri('customers/forgot-password/set-password');
    if (url == null) return _failure(_connectionErrorMessage());

    try {
      final response = await http
          .post(
        url,
        headers: _headers,
        body: jsonEncode({
          'email': _normalizeEmail(email),
          'password': password,
        }),
      )
          .timeout(_apiTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _success();
      }

      return _failure(
        _extractMessage(response, 'Failed to reset password'),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return _failure(_connectionErrorMessage(e));
    }
  }
}
