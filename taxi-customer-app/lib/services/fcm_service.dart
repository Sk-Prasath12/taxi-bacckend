import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:taxi_user/config/api_config.dart';
import 'package:taxi_user/services/session_service.dart';

/// Push notifications — mobile only (skipped on Chrome/web).
class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  bool _initialized = false;
  final Set<String> _handledMessageIds = <String>{};
  DateTime? _lastNavigationAt;

  bool get _available => !kIsWeb;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  Future<void> init([BuildContext? context]) async {
    if (!_available || _initialized) return;
    _initialized = true;
    try {
      await _messaging.requestPermission();

      FirebaseMessaging.onMessage.listen((message) {
        _showForegroundNotice(message, context);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleNotificationTap(message, context);
      });

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage, context);
      }
    } catch (error) {
      debugPrint('FCM INIT ERROR: $error');
    }
  }

  Future<void> registerTokenWithBackend({required String authToken}) async {
    if (!_available) return;
    try {
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      };
      final body = jsonEncode({'token': fcmToken});

      final url = Uri.parse(
        '${ApiConfig.apiRestBase}/notifications/save-token',
      );

      try {
        final response = await http.post(url, headers: headers, body: body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return;
        }
      } catch (_) {}
    } catch (error) {
      debugPrint('FCM TOKEN SAVE ERROR: $error');
    }
  }

  void _showForegroundNotice(RemoteMessage message, BuildContext? context) {
    try {
      final safeContext = context ?? SessionService.navigatorKey.currentContext;
      if (safeContext == null) return;
      final title = message.notification?.title ?? 'Notification';
      final body = message.notification?.body ?? '';
      ScaffoldMessenger.of(safeContext).showSnackBar(
        SnackBar(content: Text(body.isEmpty ? title : '$title: $body')),
      );
    } catch (error) {
      debugPrint('FCM FOREGROUND UI ERROR: $error');
    }
  }

  bool _shouldSkipNavigation(RemoteMessage message) {
    final id = message.messageId ?? '';
    if (id.isNotEmpty && _handledMessageIds.contains(id)) return true;
    final now = DateTime.now();
    if (_lastNavigationAt != null &&
        now.difference(_lastNavigationAt!).inMilliseconds < 600) {
      return true;
    }
    if (id.isNotEmpty) _handledMessageIds.add(id);
    _lastNavigationAt = now;
    return false;
  }

  void _handleNotificationTap(RemoteMessage message, BuildContext? context) {
    try {
      final navigator = SessionService.navigatorKey.currentState;
      if (navigator == null) return;
      if (_shouldSkipNavigation(message)) return;

      // Do not auto-open ride screens from notifications; customer starts booking from home.
      navigator.pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (error) {
      debugPrint('FCM TAP HANDLE ERROR: $error');
    }
  }
}
