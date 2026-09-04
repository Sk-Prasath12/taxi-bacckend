import 'package:flutter/material.dart';
import 'package:taxiapp/api/driver_api.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/dashboard/dashboard_page.dart';
import 'package:taxiapp/drive_page/ride_flow/ride_flow_navigator.dart';
import 'package:taxiapp/drive_page/ride_flow/ride_flow_service.dart';
import 'package:taxiapp/services/active_ride_store.dart';

/// Cancel dialog + API for pre-OTP ride stages only.
Future<bool> showDriverCancelRideDialog(BuildContext context) async {
  final reasonController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel ride?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'You can cancel only before the customer pickup OTP is verified.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Cancellation reason',
              hintText: 'e.g. Customer not reachable',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep ride')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Cancel ride'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    reasonController.dispose();
    return false;
  }

  final flow = RideFlowService.instance;
  final token = await flow.requireToken();
  if (token == null || !context.mounted) {
    reasonController.dispose();
    return false;
  }

  final result = await DriverApi.withToken(token).cancelRideResult(
        flow.rideId,
        reason: reasonController.text,
      );
  reasonController.dispose();
  if (!context.mounted) return false;

  if (!result.success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? 'Could not cancel ride'),
        backgroundColor: AppColors.danger,
      ),
    );
    return false;
  }

  await ActiveRideStore.clear();
  flow.disposeFlow();
  RideFlowNavigator.markFlowEnded();
  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardPage()),
      (route) => false,
    );
  }
  return true;
}
