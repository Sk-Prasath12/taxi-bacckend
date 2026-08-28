import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'active_ride_store.dart';

class SessionService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Legacy keys — removed on [clearRide] so old installs do not auto-resume rides.
  static const String _rideKey = 'active_ride_id';
  static const String _ridePayloadKey = 'active_ride_payload';
  static const List<String> _legacyRideKeys = [
    _rideKey,
    _ridePayloadKey,
    'current_ride_id',
    'pending_ride_id',
    'last_active_ride_id',
    'last_ride_id',
    'ride_status',
    'ride_tracking_args',
  ];

  static void redirectToLogin() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  static Future<void> clearRide() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _legacyRideKeys) {
      await prefs.remove(key);
    }
    await ActiveRideStore.clear();
  }
}
