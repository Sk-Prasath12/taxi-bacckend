import 'dart:convert';

import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../domain/services/auth_storage.dart';
import 'customer_auth_manager.dart';
import 'customer_session_store.dart';
import 'session_service.dart';

class CustomerProfile {
  final String id;
  final String name;
  final String email;
  final String? phone;

  const CustomerProfile({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: json['phone']?.toString(),
    );
  }
}

class ProfileService {
  static Future<String> _token() async {
    final token = await CustomerSessionStore.getAccessToken() ??
        await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('User not authenticated');
    }
    return token;
  }

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static String _extractMessage(http.Response response, String fallback) {
    try {
      if (response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final message = data['message'] ?? data['error'] ?? data['msg'];
          if (message is String && message.trim().isNotEmpty) {
            return message.trim();
          }
        }
      }
    } catch (_) {}
    return fallback;
  }

  static Future<void> _handleUnauthorized() async {
    if (!await CustomerAuthManager.refreshAccessToken()) {
      await CustomerAuthManager.logout();
      SessionService.redirectToLogin();
    }
  }

  static Future<CustomerProfile> getProfile() async {
    final token = await _token();
    final url = Uri.parse('${ApiConfig.baseUrl}/customers/profile');
    final response = await http.get(url, headers: _headers(token));

    if (response.statusCode == 401) {
      await _handleUnauthorized();
      throw Exception('Session expired — please sign in again');
    }
    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to load profile'));
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid profile response');
    }
    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      throw Exception('Invalid profile response');
    }
    return CustomerProfile.fromJson(user);
  }

  static Future<CustomerProfile> updateProfile({
    required String name,
    required String phone,
  }) async {
    final token = await _token();
    final url = Uri.parse('${ApiConfig.baseUrl}/customers/profile');
    final response = await http.patch(
      url,
      headers: _headers(token),
      body: jsonEncode({
        'name': name.trim(),
        'phone': phone.trim(),
      }),
    );

    if (response.statusCode == 401) {
      await _handleUnauthorized();
      throw Exception('Session expired — please sign in again');
    }
    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to update profile'));
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid update response');
    }
    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      throw Exception('Invalid update response');
    }
    return CustomerProfile.fromJson(user);
  }

  static Future<void> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    final token = await _token();
    final url = Uri.parse('${ApiConfig.baseUrl}/customers/change-password');
    final response = await http.post(
      url,
      headers: _headers(token),
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode == 401) {
      await _handleUnauthorized();
      throw Exception('Session expired — please sign in again');
    }
    if (response.statusCode != 200) {
      throw Exception(_extractMessage(response, 'Failed to change password'));
    }
  }
}
