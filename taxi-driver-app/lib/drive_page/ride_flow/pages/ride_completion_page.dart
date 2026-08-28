import 'package:flutter/material.dart';
import 'package:taxiapp/api/driver_api.dart';
import 'package:taxiapp/core/app_colors.dart';

import '../ride_flow_navigator.dart';
import '../ride_flow_routes.dart';
import '../ride_flow_service.dart';
import '../widgets/ride_flow_scaffold.dart';

/// Page 9 — Ride summary before final completion.
class RideCompletionPage extends StatefulWidget {
  const RideCompletionPage({super.key});

  @override
  State<RideCompletionPage> createState() => _RideCompletionPageState();
}

class _RideCompletionPageState extends State<RideCompletionPage> {
  final _flow = RideFlowService.instance;
  bool _loading = false;

  Future<void> _complete() async {
    final token = await _flow.requireToken();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.'), backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() => _loading = true);
    final ok = await DriverApi.withToken(token).completeRide(_flow.rideId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not complete ride'), backgroundColor: AppColors.danger),
      );
      return;
    }
    _flow.mergeRide({..._flow.ride, 'status': 'COMPLETED'});
    await RideFlowNavigator.go(context, RideFlowRoutes.success);
  }

  @override
  Widget build(BuildContext context) {
    final ride = _flow.ride;
    final dist = (ride['actual_distance_km'] as num?)?.toDouble() ?? _flow.tripTracker.distanceKm;
    final duration = (ride['duration_min'] as num?)?.toDouble() ?? _flow.tripTracker.durationMin;
    final paymentStatus =
        (ride['payment_status'] ?? ride['paymentStatus'] ?? 'SUCCESS').toString().toUpperCase();
    final mode = (ride['payment_mode'] ?? 'CASH').toString().toUpperCase();

    return RideFlowScaffold(
      title: 'Ride Summary',
      canPop: true,
      bottomButton: rideFlowButton(
        label: 'COMPLETE RIDE',
        onPressed: _loading ? null : _complete,
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ride summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('Distance: ${dist.toStringAsFixed(2)} km'),
                Text('Duration: ${duration.round()} min'),
                Text('Final fare: ₹${_flow.fare.toStringAsFixed(0)}'),
                Text('Payment: ${mode == 'ONLINE' ? 'Razorpay' : 'Cash'}'),
                Text('Payment status: $paymentStatus'),
                const SizedBox(height: 8),
                Text('Customer: ${_flow.customerName()}'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
