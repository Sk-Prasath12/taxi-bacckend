import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/active_ride_store.dart';
import 'ride_flow_routes.dart';
import 'ride_flow_service.dart';

class RideFlowNavigator {
  static bool _inFlow = false;

  static bool get isInFlow => _inFlow;

  /// Entry from accept / resume — opens the correct page for ride status.
  static Future<void> open(BuildContext context, Map<String, dynamic>? rideData) async {
    _inFlow = true;
    final flow = RideFlowService.instance;
    flow.prepareRide(rideData ?? <String, dynamic>{});
    unawaited(ActiveRideStore.save(flow.ride));
    if (!context.mounted) return;
    final route = routeForRide(flow.ride);
    await Navigator.pushNamedAndRemoveUntil(
      context,
      route,
      (r) => r.isFirst,
      arguments: flow.ride,
    );
    unawaited(flow.startBackgroundServices());
  }

  static Future<void> go(BuildContext context, String routeName) async {
    await RideFlowService.instance.save();
    if (!context.mounted) return;
    await Navigator.pushReplacementNamed(
      context,
      routeName,
      arguments: RideFlowService.instance.ride,
    );
  }

  static String routeForRide(Map<String, dynamic> ride) {
    final status = (ride['status'] ?? 'DRIVER_ASSIGNED').toString().toUpperCase();
    final paymentStatus = (ride['payment_status'] ?? ride['paymentStatus'] ?? '').toString().toUpperCase();
    final dropVerified = ride['drop_otp_verified'] == true;
    final dropReached = ride['drop_reached'] == true || ride['drop_otp'] != null;
    final otpVerified = ride['otp_verified'] == true || status == 'STARTED';

    if (status == 'COMPLETED') return RideFlowRoutes.success;
    if (dropVerified && paymentStatus == 'SUCCESS') return RideFlowRoutes.success;
    if (dropVerified || status == 'COMPLETED_PENDING_PAYMENT') return RideFlowRoutes.payment;
    if (dropReached && !dropVerified) return RideFlowRoutes.dropReached;
    if (status == 'IN_TRANSIT' || status == 'PICKED_UP') return RideFlowRoutes.ongoing;
    if (otpVerified || status == 'STARTED') return RideFlowRoutes.ongoing;
    if (status == 'ARRIVED_AT_PICKUP' || status == 'ARRIVED') return RideFlowRoutes.arrived;
    return RideFlowRoutes.accepted;
  }

  static Future<void> resumeIfNeeded(BuildContext context) async {
    if (_inFlow) return;
    final stored = await ActiveRideStore.load();
    if (stored == null || ActiveRideStore.isTerminalStatus(stored['status']?.toString())) {
      return;
    }
    if (!context.mounted) return;
    await open(context, stored);
  }

  static void markFlowStarting() => _inFlow = true;

  static void markFlowEnded() => _inFlow = false;
}
