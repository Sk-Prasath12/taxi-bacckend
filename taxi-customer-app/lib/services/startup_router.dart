import '../utils/ride_locations.dart';

class StartupDestination {
  final String route;
  final Map<String, dynamic>? arguments;

  const StartupDestination(this.route, {this.arguments});
}

/// Resolves initial screen after session bootstrap.
class StartupRouter {
  static const _searchingStatuses = {'SEARCHING_DRIVER', 'SEARCHING'};
  static const _trackingStatuses = {
    'DRIVER_ASSIGNED',
    'ACCEPTED',
    'DRIVER_ARRIVING',
    'DRIVER_ARRIVED',
    'ARRIVED_AT_PICKUP',
    'ARRIVED',
    'OTP_VERIFIED',
    'STARTED',
    'PICKED_UP',
    'IN_TRANSIT',
    'IN_PROGRESS',
    'TRIP_STARTED',
    'DROP_REACHED',
  };
  static const _paymentStatuses = {
    'DROP_OTP_VERIFIED',
    'PAYMENT_PENDING',
  };

  static StartupDestination home() => const StartupDestination('/home');

  static StartupDestination fromActiveRide(Map<String, dynamic>? ride) {
    if (ride == null || ride.isEmpty) {
      return home();
    }

    final rideId = (ride['ride_id'] ?? ride['id'] ?? '').toString();
    if (rideId.isEmpty) return home();

    final status = (ride['status'] ?? '').toString().toUpperCase();
    final paymentStatus = (ride['payment_status'] ?? '').toString().toUpperCase();
    final paymentMode = (ride['payment_mode'] ?? '').toString().toUpperCase();
    final args = _rideArguments(ride);

    if (status == 'CANCELLED' || status == 'CANCELLED_BY_CUSTOMER') {
      return home();
    }

    if (_paymentStatuses.contains(status)) {
      return StartupDestination('/ride-payment', arguments: {'rideId': rideId});
    }

    if (status == 'COMPLETED') {
      final needsPayment =
          paymentStatus == 'PENDING' || paymentStatus.isEmpty;
      if (needsPayment && paymentMode != 'CASH') {
        return StartupDestination('/ride-payment', arguments: {'rideId': rideId});
      }
      if (needsPayment && paymentMode == 'CASH') {
        return StartupDestination('/ride-payment', arguments: {'rideId': rideId});
      }
      return home();
    }

    if (status == 'PENDING_CONFIRMATION') {
      return StartupDestination('/booking-summary', arguments: args);
    }

    if (_searchingStatuses.contains(status)) {
      return StartupDestination('/driver-searching', arguments: args);
    }

    if (_trackingStatuses.contains(status)) {
      return StartupDestination(
        '/ride-tracking',
        arguments: buildRideTrackingArguments(args, ride),
      );
    }

    // Unknown mid-trip status → tracking, never endless searching.
    return StartupDestination(
      '/ride-tracking',
      arguments: buildRideTrackingArguments(args, ride),
    );
  }

  static Map<String, dynamic> _rideArguments(Map<String, dynamic> ride) {
    final pickup = ride['pickup'];
    final drop = ride['drop'];
    final pickupLatLng = latLngFromMap(pickup);
    final dropLatLng = latLngFromMap(drop);

    return {
      'rideId': (ride['ride_id'] ?? ride['id'] ?? '').toString(),
      if (pickupLatLng != null) 'pickupLatLng': pickupLatLng,
      if (dropLatLng != null) 'dropoffLatLng': dropLatLng,
      if (pickup is Map) 'pickupAddress': pickup['address']?.toString(),
      if (drop is Map) 'dropAddress': drop['address']?.toString(),
      'paymentMethod': ride['payment_mode']?.toString() ?? 'Cash',
      'vehicleTypeId': ride['vehicle_type_id']?.toString(),
      'fare': ride['fare'],
      'distanceKm': ride['distance_km'],
      'durationMin': ride['duration_min'],
      'statusPayload': ride,
      'initialStatus': ride['status']?.toString(),
    };
  }
}
