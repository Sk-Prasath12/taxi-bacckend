import 'package:taxiapp/api/driver_api.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';

/// Loads driver earnings from completed rides (today / week / month / year).
class DriverEarningsService {
  DriverEarningsService._();
  static final DriverEarningsService instance = DriverEarningsService._();

  static String periodParam(String uiLabel) {
    switch (uiLabel.toLowerCase()) {
      case 'weekly':
      case 'this week':
        return 'week';
      case 'monthly':
      case 'this month':
        return 'month';
      case 'yearly':
      case 'this year':
        return 'year';
      default:
        return 'today';
    }
  }

  Future<Map<String, dynamic>> fetchSummary(String uiPeriod) async {
    final token = AuthService().token;
    if (token == null) return _emptySummary();

    final raw = await DriverApi.withToken(token).getEarningsSummary(periodParam(uiPeriod));
    if (raw == null) return _emptySummary();

    final data = raw['data'] is Map ? Map<String, dynamic>.from(raw['data'] as Map) : raw;

    final ridesList = (data['rides_list'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final dailyRaw = data['daily_breakdown'];
    final dailyBreakdown = dailyRaw is List
        ? dailyRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    return {
      'total': (data['total'] as num?)?.toDouble() ?? 0,
      'rides': (data['rides'] as num?)?.toInt() ?? ridesList.length,
      'hours': (data['hours'] as num?)?.toDouble() ?? 0,
      'cash': (data['cash'] as num?)?.toDouble() ?? 0,
      'card': (data['card'] as num?)?.toDouble() ?? 0,
      'digital': (data['digital'] as num?)?.toDouble() ?? 0,
      'commission': (data['commission'] as num?)?.toDouble() ?? 0,
      'net': (data['net'] as num?)?.toDouble() ?? 0,
      'commission_percent': (data['commission_percent'] as num?)?.toInt() ?? 15,
      'period_label': data['period_label']?.toString(),
      'daily_breakdown': dailyBreakdown,
      'rides_list': ridesList,
    };
  }

  Future<double> fetchTodayTotal() async {
    final s = await fetchSummary('Today');
    return (s['total'] as num?)?.toDouble() ?? 0;
  }

  Map<String, dynamic> _emptySummary() => {
        'total': 0.0,
        'rides': 0,
        'hours': 0.0,
        'cash': 0.0,
        'card': 0.0,
        'digital': 0.0,
        'commission': 0.0,
        'net': 0.0,
        'commission_percent': 15,
        'period_label': null,
        'daily_breakdown': <Map<String, dynamic>>[],
        'rides_list': <Map<String, dynamic>>[],
      };
}
