import 'package:intl/intl.dart';

/// Normalizes ride JSON from backend history APIs for UI.
class RideHistoryFormat {
  static String rideId(Map<String, dynamic> m) =>
      (m['ride_id'] ?? m['rideId'] ?? m['id'] ?? '').toString();

  static String addressFrom(Map<String, dynamic> m, {required String nestedKey}) {
    final nested = m[nestedKey];
    if (nested is Map) {
      final addr = nested['address']?.toString().trim();
      if (addr != null && addr.isNotEmpty) return addr;
    }
    final flat = nestedKey == 'pickup'
        ? (m['pickupAddress'] ?? m['pickup_address'])
        : (m['dropAddress'] ?? m['drop_address'] ?? m['dropoffAddress']);
    if (flat != null && flat.toString().trim().isNotEmpty) {
      return flat.toString().trim();
    }
    return nestedKey == 'pickup' ? 'Pickup location' : 'Drop location';
  }

  static double fareAmount(Map<String, dynamic> m) {
    final fare = m['fare'] ?? m['totalAmount'] ?? m['total_amount'];
    if (fare is num) return fare.toDouble();
    if (fare is String) return double.tryParse(fare) ?? 0;
    return 0;
  }

  static String status(Map<String, dynamic> m) =>
      (m['status']?.toString() ?? 'PENDING').toUpperCase();

  static String? driverName(Map<String, dynamic> m) {
    final driver = m['driver'];
    if (driver is Map) {
      final name = driver['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }

  static String? driverPhone(Map<String, dynamic> m) {
    final driver = m['driver'];
    if (driver is Map) {
      final phone = driver['phone']?.toString().trim();
      if (phone != null && phone.isNotEmpty) return phone;
    }
    return null;
  }

  static DateTime? rideDateTime(Map<String, dynamic> m) {
    final raw = m['createdAt'] ?? m['created_at'] ?? m['updatedAt'] ?? m['updated_at'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  static String formatDateTime(Map<String, dynamic> m) {
    final dt = rideDateTime(m);
    if (dt == null) return '—';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  static String formatDayHeader(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEEE, dd MMM yyyy').format(day);
  }

  static String dayKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Groups rides newest-first; each group is sorted newest-first.
  static List<({String key, DateTime day, List<Map<String, dynamic>> rides})>
      groupByDay(List<Map<String, dynamic>> rides) {
    final map = <String, List<Map<String, dynamic>>>{};
    final dayByKey = <String, DateTime>{};

    for (final ride in rides) {
      final dt = rideDateTime(ride) ?? DateTime.now();
      final key = dayKey(dt);
      dayByKey.putIfAbsent(key, () => DateTime(dt.year, dt.month, dt.day));
      map.putIfAbsent(key, () => []).add(ride);
    }

    final keys = map.keys.toList()
      ..sort((a, b) => dayByKey[b]!.compareTo(dayByKey[a]!));

    return [
      for (final key in keys)
        (
          key: key,
          day: dayByKey[key]!,
          rides: map[key]!
            ..sort((a, b) {
              final ba = rideDateTime(b);
              final aa = rideDateTime(a);
              if (ba == null || aa == null) return 0;
              return ba.compareTo(aa);
            }),
        ),
    ];
  }

  static ({int trips, double spent}) daySummary(List<Map<String, dynamic>> rides) {
    var spent = 0.0;
    for (final r in rides) {
      if (status(r) == 'COMPLETED') spent += fareAmount(r);
    }
    return (trips: rides.length, spent: spent);
  }

  static ({int totalTrips, double totalSpent, int completed}) overallSummary(
    List<Map<String, dynamic>> rides,
  ) {
    var totalSpent = 0.0;
    var completed = 0;
    for (final r in rides) {
      final st = status(r);
      if (st == 'COMPLETED') {
        completed++;
        totalSpent += fareAmount(r);
      }
    }
    return (totalTrips: rides.length, totalSpent: totalSpent, completed: completed);
  }
}
