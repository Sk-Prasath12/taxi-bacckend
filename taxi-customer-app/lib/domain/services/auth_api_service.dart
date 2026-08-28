/// Auth API service – connects taxi_user to taxi_app_backend customer routes.
library;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

/// Timeout for API calls (connection can be slow on same WiFi).
const Duration _apiTimeout = Duration(seconds: 25);

class AuthApiService {
  static final AuthApiService _instance = AuthApiService._internal();
  factory AuthApiService() => _instance;
  AuthApiService._internal();

  static String get _customersBase => '${ApiConfig.apiBaseUrl}/customers';

  /// Build user-friendly message from backend error or status. Handles 500 / internal errors.
  static String _extractErrorMessage(Map<String, dynamic> decoded, int statusCode, String rawBody) {
    Object? m = decoded['message'] ?? decoded['error'] ?? decoded['msg'];
    final String msg = m is String ? m : (m?.toString() ?? '').trim();
    final bool isInternal = statusCode >= 500 ||
        msg.toLowerCase().contains('internal') ||
        msg.toLowerCase().contains('server error');
    if (isInternal && msg.isEmpty) {
      return 'Server error. Please try again later.';
    }
    if (isInternal) {
      return '$msg Check backend logs and database connection.';
    }
    if (msg.isNotEmpty) return msg;
    if (rawBody.isNotEmpty && !rawBody.trimLeft().startsWith('{')) {
      return 'Request failed (${statusCode}). Server may be misconfigured.';
    }
    return 'Request failed (${statusCode}).';
  }

  /// Quick health check (GET /api/v1/health). Use to show connection status on signup.
  static const Duration _healthTimeout = Duration(seconds: 6);

  Future<bool> checkServerHealth() async {
    try {
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/v1/health');
      final response = await http.get(uri).timeout(
        _healthTimeout,
        onTimeout: () => throw TimeoutException('timeout'),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    if (!ApiConfig.useBackend) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (path.endsWith('/login')) {
        return {
          'token': 'test-access-token',
          'refreshToken': 'test-refresh-token',
          'user': {'email': body?['email'], 'name': 'Test User'},
        };
      }
      return {
        'success': true,
        'mock': true,
        'path': path,
        'message': 'AuthApiService mock response (backend disabled)',
      };
    }

    final uri = Uri.parse('$_customersBase$path');
    final headers = {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': ApiConfig.authHeader(accessToken),
    };
    try {
      final Future<http.Response> future = method == 'GET'
          ? http.get(uri, headers: headers)
          : http.post(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );
      final response = await future.timeout(
        _apiTimeout,
        onTimeout: () => throw TimeoutException('Connection timed out. Please try again.'),
      );
      Map<String, dynamic> decoded = {};
      try {
        if (response.body.isNotEmpty) {
          final decodedRaw = jsonDecode(response.body);
          if (decodedRaw is Map<String, dynamic>) decoded = decodedRaw;
        }
      } catch (_) {}

      if (response.statusCode >= 400) {
        final msg = _extractErrorMessage(decoded, response.statusCode, response.body);
        throw Exception(msg);
      }
      return decoded;
    } on SocketException catch (_) {
      throw Exception('Unable to connect to the server. Check your internet connection.');
    } on TimeoutException catch (e) {
      throw Exception(
        e.message?.isNotEmpty == true ? e.message! : 'Connection timed out. Please try again.',
      );
    }
  }

  /// POST /customers/register/email – creates user and sends OTP to email.
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    String role = 'customer',
  }) async {
    return _request('POST', '/register/email', body: {
      'name': name,
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
    });
  }

  /// POST /customers/register/email – resend OTP.
  Future<Map<String, dynamic>> sendRegistrationOtp(String email) async {
    return _request('POST', '/register/email', body: {
      'email': email.trim().toLowerCase(),
    });
  }

  /// POST /customers/register/verify-otp – verify OTP (signup flow).
  Future<Map<String, dynamic>> verifyRegistrationOtp(String email, String otp) async {
    return _request('POST', '/register/verify-otp', body: {
      'email': email.trim().toLowerCase(),
      'otp': otp.trim(),
    });
  }

  /// POST /customers/register/set-password – set password after signup verify.
  Future<Map<String, dynamic>> setPassword(String email, String otp, String password) async {
    return _request('POST', '/register/set-password', body: {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
  }

  /// POST /customers/login – email + password.
  Future<Map<String, dynamic>> login(String email, String password) async {
    return _request('POST', '/login', body: {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
  }

  /// POST /customers/forgot-password/email – send OTP for password reset.
  Future<Map<String, dynamic>> forgetPassword(String email) async {
    return _request('POST', '/forgot-password/email', body: {
      'email': email.trim().toLowerCase(),
    });
  }

  /// POST /customers/forgot-password/set-password – reset password with OTP.
  Future<Map<String, dynamic>> resetPassword(String email, String otp, String password) async {
    return _request('POST', '/forgot-password/set-password', body: {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
  }
}
