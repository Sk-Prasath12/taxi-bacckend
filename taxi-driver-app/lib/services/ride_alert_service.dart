import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Ring + popup when a new customer ride arrives.
class RideAlertService {
  static Timer? _pulseTimer;

  static void stopRing() {
    _pulseTimer?.cancel();
    _pulseTimer = null;
  }

  static void startRing() {
    stopRing();
    HapticFeedback.heavyImpact();
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      HapticFeedback.mediumImpact();
    });
  }

  static Future<void> showIncomingRideDialog(
    BuildContext context, {
    required Map<String, dynamic> ride,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
  }) async {
    if (!context.mounted) return;
    startRing();

    final pickup = ride['pickup']?.toString() ?? 'Pickup';
    final dropoff = ride['dropoff']?.toString() ?? 'Drop';
    final tripKm = (ride['tripDistanceKm'] as num?)?.toDouble() ??
        double.tryParse(ride['distance']?.toString() ?? '') ??
        0;
    final fare = (ride['fare'] as num?)?.toDouble() ?? 0;
    final pay = ride['paymentMode']?.toString() ?? 'CASH';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.orange[800], size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'New ride request',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pickup: $pickup', maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text('Drop: $dropoff', maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Text('Trip: ${tripKm.toStringAsFixed(1)} km'),
            Text('Approx fare: ₹${fare.toStringAsFixed(0)}'),
            Text('Payment: $pay'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              stopRing();
              Navigator.pop(ctx);
              onDecline();
            },
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () {
              stopRing();
              Navigator.pop(ctx);
              onAccept();
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    stopRing();
  }
}
