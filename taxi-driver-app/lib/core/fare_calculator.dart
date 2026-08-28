import 'dart:math' as math;

/// Central fare rules for driver + customer apps.
class FareCalculator {
  FareCalculator._();

  /// Distance rate during live trip (₹/km).
  static const double perKm = 30;

  /// Time / waiting fare after free minutes (₹/min).
  static const double perMin = 5;

  /// First minute of trip time is free for the customer.
  static const double freeWaitingMinutes = 1;

  /// Charged to customer on cancel; credited to driver.
  static const double cancellationFee = 10;

  static double billableMinutes(double durationMin) {
    final extra = durationMin - freeWaitingMinutes;
    if (extra <= 0) return 0;
    return math.max(1, extra.ceil()).toDouble();
  }

  static double timeCharge(double durationMin) => billableMinutes(durationMin) * perMin;

  static double distanceCharge(double distanceKm, {double? ratePerKm}) =>
      distanceKm * (ratePerKm ?? perKm);

  /// Fare from actual GPS km only (customer gets off anywhere).
  static double kmOnlyFare(double distanceKm, {double? ratePerKm}) =>
      distanceCharge(distanceKm, ratePerKm: ratePerKm);

  /// Live trip fare: distance + time (1st min free, then ₹5/min).
  static double tripFare({
    required double distanceKm,
    required double durationMin,
    double baseFare = 0,
    double? ratePerKm,
  }) {
    final total = baseFare +
        distanceCharge(distanceKm, ratePerKm: ratePerKm) +
        timeCharge(durationMin);
    return double.parse(total.toStringAsFixed(2));
  }

  /// Booking estimate when duration unknown — uses ~2 min/km city average.
  static double estimateBookingFare({
    required double distanceKm,
    double baseFare = 0,
    double? ratePerKm,
  }) {
    final estimatedMin = distanceKm * 2;
    return tripFare(
      distanceKm: distanceKm,
      durationMin: estimatedMin,
      baseFare: baseFare,
      ratePerKm: ratePerKm,
    );
  }

  static Map<String, double> breakdown({
    required double distanceKm,
    required double durationMin,
    double baseFare = 0,
    double? ratePerKm,
  }) {
    final dist = distanceCharge(distanceKm, ratePerKm: ratePerKm);
    final time = timeCharge(durationMin);
    final total = baseFare + dist + time;
    return {
      'base': baseFare,
      'distance': dist,
      'time': time,
      'total': double.parse(total.toStringAsFixed(2)),
      'billable_minutes': billableMinutes(durationMin),
    };
  }
}
