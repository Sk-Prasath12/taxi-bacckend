import 'dart:async';

import 'package:flutter/material.dart';
import 'package:taxiapp/services/active_ride_store.dart';

import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/taxi_icons.dart';

import '../ride_flow_navigator.dart';
import '../ride_flow_service.dart';

/// Page 10 — Success; auto-return to online home after 3 seconds.
class RideSuccessPage extends StatefulWidget {
  const RideSuccessPage({super.key});

  @override
  State<RideSuccessPage> createState() => _RideSuccessPageState();
}

class _RideSuccessPageState extends State<RideSuccessPage> {
  final _flow = RideFlowService.instance;
  int _seconds = 3;

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _seconds--);
      if (_seconds <= 0) {
        t.cancel();
        _goHome();
      }
    });
  }

  Future<void> _goHome() async {
    _flow.disposeFlow();
    RideFlowNavigator.markFlowEnded();
    await ActiveRideStore.clear();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final ride = _flow.ride;
    final dist = (ride['actual_distance_km'] as num?)?.toDouble() ?? _flow.tripTracker.distanceKm;
    final paymentStatus =
        (ride['payment_status'] ?? 'SUCCESS').toString().toUpperCase();
    final mode = (ride['payment_mode'] ?? ride['paymentMode'] ?? 'CASH').toString().toUpperCase();
    final walletBal = (ride['wallet_balance'] as num?)?.toDouble();
    final earnings = (ride['driver_earnings'] as num?)?.toDouble();

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ride Complete'),
          backgroundColor: AppColors.black,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(TaxiIcons.accept, color: AppColors.green, size: 88),
                const SizedBox(height: 20),
                const Text(
                  'RIDE COMPLETED SUCCESSFULLY',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text('Total fare: ₹${_flow.fare.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                Text('Distance: ${dist.toStringAsFixed(2)} km'),
                Text('Payment: ${mode == 'ONLINE' ? 'Razorpay' : 'Cash'} · $paymentStatus'),
                if (earnings != null)
                  Text(
                    '₹${earnings.toStringAsFixed(0)} credited to wallet',
                    style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600),
                  ),
                if (walletBal != null)
                  Text('Wallet balance: ₹${walletBal.toStringAsFixed(2)}'),
                const SizedBox(height: 24),
                Text('Returning to home in $_seconds s…', style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                TextButton(onPressed: _goHome, child: const Text('Go now')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
