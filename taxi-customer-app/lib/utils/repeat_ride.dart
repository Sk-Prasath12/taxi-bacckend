import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/ride_session_cleanup.dart';

/// Re-books using pickup/drop from a past ride (same UI flow as new booking).
class RepeatRide {
  static Future<void> fromHistoryRide(
    BuildContext context,
    Map<String, dynamic> ride,
  ) async {
    final pickup = ride['pickup'];
    final drop = ride['drop'];
    if (pickup is! Map || drop is! Map) {
      _snack(context, 'This ride has no saved locations to repeat.');
      return;
    }
    final plat = pickup['lat'];
    final plng = pickup['lng'];
    final dlat = drop['lat'];
    final dlng = drop['lng'];
    if (plat is! num || plng is! num || dlat is! num || dlng is! num) {
      _snack(context, 'Location coordinates are missing for this ride.');
      return;
    }

    await RideSessionCleanup.resetForNewSession();
    if (!context.mounted) return;

    Navigator.pushNamed(
      context,
      '/taxi-selection',
      arguments: {
        'pickupLatLng': LatLng(plat.toDouble(), plng.toDouble()),
        'dropoffLatLng': LatLng(dlat.toDouble(), dlng.toDouble()),
        'pickupAddress': pickup['address']?.toString() ?? '',
        'dropoffAddress': drop['address']?.toString() ?? '',
        'pickup': pickup['address']?.toString() ?? '',
        'dropoff': drop['address']?.toString() ?? '',
      },
    );
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
