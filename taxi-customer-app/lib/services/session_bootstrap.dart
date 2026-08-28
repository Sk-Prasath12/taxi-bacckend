import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:taxi_user/services/customer_auth_manager.dart';
import 'package:taxi_user/services/fcm_service.dart';
import 'package:taxi_user/services/profile_service.dart';
import 'package:taxi_user/services/socket_service.dart';

/// Saves auth session, profile data, and starts socket/FCM without blocking navigation on web.
class SessionBootstrap {
  static Future<void> afterLogin({
    required String token,
    required String email,
    String? displayName,
    String? refreshToken,
    Map<String, dynamic>? user,
    BuildContext? context,
  }) async {
    await CustomerAuthManager.persistLogin(
      accessToken: token,
      refreshToken: refreshToken,
      email: email,
      name: displayName,
      phone: user?['phone']?.toString(),
      user: user,
    );

    try {
      final profile = await ProfileService.getProfile();
      await CustomerAuthManager.syncProfileMap({
        'id': profile.id,
        'name': profile.name,
        'email': profile.email,
        'phone': profile.phone ?? '',
        'role': 'customer',
      });
    } catch (e) {
      debugPrint('Profile sync after login skipped: $e');
    }

    try {
      await SocketService.instance.init();
      SocketService.instance.joinCustomerRoom();
    } catch (e) {
      debugPrint('Socket setup skipped: $e');
    }

    if (!kIsWeb) {
      try {
        await FCMService.instance.init(context);
        await FCMService.instance.registerTokenWithBackend(authToken: token);
      } catch (e) {
        debugPrint('FCM setup skipped: $e');
      }
    }
  }
}
