import 'session_service.dart';
import 'ride_service.dart';

/// Clears local ride cache and cancels any open ride on the server.
/// Called on splash/login and after trip completion — never to resume a ride UI.
class RideSessionCleanup {
  static Future<void> clearLocalOnly() async {
    await SessionService.clearRide();
  }

  static Future<void> resetForNewSession() async {
    await clearLocalOnly();
    await RideService.abandonStaleActiveRide();
  }
}
