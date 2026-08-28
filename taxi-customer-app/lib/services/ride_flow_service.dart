import 'package:flutter/foundation.dart';
import 'package:taxi_user/services/ride_service.dart';
import 'package:taxi_user/services/socket_service.dart';

/// Connects customer socket to a ride so driver accept / live GPS reach the app.
class RideFlowService {
  /// After [RideService.confirmRide] — joins rooms before driver-searching screen.
  static Future<void> afterConfirmRide(String rideId) async {
    if (rideId.isEmpty) return;
    final socket = SocketService.instance;
    await socket.connect();
    socket.joinCustomerRoom();
    socket.joinCustomerRide(rideId);
    socket.joinRideRoom(rideId);
    if (kDebugMode) {
      // ignore: avoid_print
      print('RideFlow: customer socket ready for ride $rideId (drivers receive new_ride on confirm)');
    }

    try {
      final status = await RideService.getRideStatus(rideId);
      await RideService.cacheActiveRide(status);
    } catch (_) {}
  }
}
