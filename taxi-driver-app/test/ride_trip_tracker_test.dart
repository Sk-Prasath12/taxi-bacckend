import 'package:flutter_test/flutter_test.dart';
import 'package:taxiapp/core/fare_calculator.dart';
import 'package:taxiapp/services/ride_trip_tracker.dart';

void main() {
  group('FareCalculator', () {
    test('distance only when within free minute', () {
      expect(FareCalculator.tripFare(distanceKm: 1, durationMin: 0), 30);
      expect(FareCalculator.tripFare(distanceKm: 3, durationMin: 1), 90);
    });

    test('adds ₹5/min after 1st free minute', () {
      expect(FareCalculator.tripFare(distanceKm: 3, durationMin: 10), 135);
    });

    test('cancellation fee constant', () {
      expect(FareCalculator.cancellationFee, 10);
    });
  });

  group('RideTripTracker fare calculation', () {
    test('uses distance + time fare', () {
      final tracker = RideTripTracker();
      expect(tracker.estimateFare(distanceKm: 3, durationMin: 0), 90);
      expect(tracker.estimateFare(distanceKm: 3, durationMin: 10), 135);
    });
  });
}
