import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'customer_auth_manager.dart';
import 'customer_session_store.dart';
import 'error_handler.dart';
import 'network_service.dart';
import 'session_service.dart';

class ApiService {
  static Future<Map<String, dynamic>?> get(
    String path, {
    BuildContext? context,
  }) async {
    if (!(await NetworkService.isOnline())) {
      if (context != null && context.mounted) {
        ErrorHandler.show(context, "No Internet Connection");
      }
      return null;
    }

    final token = await CustomerSessionStore.getAccessToken();
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        // Try refresh once; keep session if refresh fails (do not force logout).
        await CustomerAuthManager.refreshAccessToken();
        return null;
      }

      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      if (context != null && context.mounted) {
        ErrorHandler.show(context, "Server error");
      }
      return null;
    }
  }
}
