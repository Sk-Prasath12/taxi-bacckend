/// OSRM-based fare calculation for the taxi customer app.
///
/// Formula: fare = max(distance_km × rate, rate)
/// Short/nearby trips always charge at least 1 km at the vehicle rate.
class FareCalculator {
  static const double ratePerKm = 40.0;

  static const Map<String, double> vehicleRates = {
    'Bike': 10,
    'Auto': 20,
    'Mini': 30,
    'Sedan': 40,
    'SUV': 50,
    'Premium Sedan': 60,
    'Premium SUV': 70,
    'XL': 80,
    'Electric': 90,
    'Accessible': 100,
    // Legacy aliases
    'Small 5 Seater Car': 30,
    '5 Seater': 30,
    'Big 7 Seater Car': 70,
    '7 Seater': 70,
  };

  static double calculateFare(double distanceKm, {double? ratePerKmOverride}) {
    final rate = ratePerKmOverride ?? ratePerKm;
    if (rate <= 0) return 0;
    final raw = distanceKm * rate;
    return _round(raw < rate ? rate : raw);
  }

  static String formatFare(double fare) => '₹${fare.toStringAsFixed(0)}';

  static String formatDistance(double km) => '${km.toStringAsFixed(1)} km';

  static String formatDuration(double minutes) =>
      '${minutes.toStringAsFixed(0)} min';

  static double estimateEtaMinutes(double distanceKm) {
    if (distanceKm <= 0) return 5;
    return (distanceKm / 30.0 * 60.0).ceilToDouble();
  }

  static double _round(double v) => double.parse(v.toStringAsFixed(0));
}
