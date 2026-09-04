/// OSRM-based fare calculation for the taxi customer app.
///
/// Formula: fare = max(distance_km × rate, rate)
/// Short/nearby trips always charge at least 1 km at the vehicle rate.
class FareCalculator {
  static const double ratePerKm = 40.0;

  static const Map<String, double> vehicleRates = {
    'Bike': 10,
    'Auto': 20,
    '5 Seater': 35,
    '7 Seater': 55,
    // Legacy aliases
    'Mini': 35,
    'Sedan': 35,
    'SUV': 55,
    'Premium Sedan': 35,
    'Premium SUV': 55,
    'XL': 55,
    'Electric': 35,
    'Accessible': 35,
    'Small 5 Seater Car': 35,
    'Big 7 Seater Car': 55,
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
