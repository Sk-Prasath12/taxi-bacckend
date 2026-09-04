import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:taxiapp/api/api_constants.dart';

class VehicleTypeOption {
  final String id;
  final String code;
  final String name;
  final String displayLabel;
  final double perKmRate;
  final int maxPassengers;

  const VehicleTypeOption({
    required this.id,
    required this.code,
    required this.name,
    required this.displayLabel,
    required this.perKmRate,
    required this.maxPassengers,
  });
}

/// Canonical codes — must match backend `ensure-canonical-vehicles` (4 types only).
const kCanonicalVehicleCodes = [
  'BIKE',
  'AUTO',
  'FIVE_SEATER',
  'SEVEN_SEATER',
];

const kCanonicalVehicleNames = [
  'Bike',
  'Auto',
  '5 Seater',
  '7 Seater',
];

String vehicleDisplayLabel(String backendName, {String? code}) {
  switch ((code ?? '').toUpperCase()) {
    case 'BIKE':
      return 'Bike';
    case 'AUTO':
      return 'Auto';
    case 'FIVE_SEATER':
    case 'SEDAN':
    case 'MINI':
    case 'CAR_5_SEATER':
    case '5_SEATER':
      return '5 Seater';
    case 'SEVEN_SEATER':
    case 'SUV':
    case 'CAR_7_SEATER':
    case '7_SEATER':
    case 'XL':
      return '7 Seater';
  }
  switch (backendName.trim().toLowerCase()) {
    case 'bike':
      return 'Bike';
    case 'auto':
      return 'Auto';
    case '5 seater':
    case 'sedan':
    case 'mini':
    case 'small 5 seater car':
      return '5 Seater';
    case '7 seater':
    case 'suv':
    case 'big 7 seater car':
      return '7 Seater';
    default:
      return backendName;
  }
}

String? _normalizeCode(String? code, String name) {
  final c = (code ?? '').trim().toUpperCase();
  if (kCanonicalVehicleCodes.contains(c)) return c;
  if (c == 'CAR_5_SEATER' || c == '5_SEATER' || c == 'SEDAN' || c == 'MINI' || c == 'PREMIUM_SEDAN') {
    return 'FIVE_SEATER';
  }
  if (c == 'CAR_7_SEATER' || c == '7_SEATER' || c == 'SUV' || c == 'PREMIUM_SUV' || c == 'XL') {
    return 'SEVEN_SEATER';
  }
  final n = name.trim().toLowerCase();
  if (n == 'bike' || n.contains('bike') || n.contains('motor')) return 'BIKE';
  if (n == 'auto' || n.contains('auto')) return 'AUTO';
  if (n.contains('5 seater') || n == 'sedan' || n == 'mini') return 'FIVE_SEATER';
  if (n.contains('7 seater') || n == 'suv' || n.contains('xl')) return 'SEVEN_SEATER';
  return null;
}

class VehicleTypeService {
  static List<VehicleTypeOption>? _cache;

  static Future<List<VehicleTypeOption>> fetchActive({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null && _cache!.isNotEmpty) return _cache!;
    final uri = Uri.parse('${ApiConstants.apiRestBase}/vehicle-types/active');
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Could not load vehicle types (${res.statusCode})');
    }
    final body = jsonDecode(res.body);
    final list = body is List
        ? body
        : (body is Map && body['data'] is List)
            ? body['data'] as List
            : <dynamic>[];

    final mapped = <VehicleTypeOption>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final name = (m['name'] ?? '').toString();
      final code = _normalizeCode(m['code']?.toString(), name);
      if (code == null || !kCanonicalVehicleCodes.contains(code)) continue;
      final id = (m['id'] ?? m['_id'] ?? '').toString();
      if (id.isEmpty) continue;
      mapped.add(
        VehicleTypeOption(
          id: id,
          code: code,
          name: name,
          displayLabel: vehicleDisplayLabel(name, code: code),
          perKmRate: (m['per_km_rate'] as num?)?.toDouble() ??
              (m['perKmRate'] as num?)?.toDouble() ??
              0,
          maxPassengers: (m['max_passengers'] as num?)?.toInt() ??
              (m['maxPassengers'] as num?)?.toInt() ??
              4,
        ),
      );
    }

    // Prefer one entry per canonical code (first wins).
    final byCode = <String, VehicleTypeOption>{};
    for (final v in mapped) {
      byCode.putIfAbsent(v.code, () => v);
    }
    final ordered = kCanonicalVehicleCodes
        .where(byCode.containsKey)
        .map((c) => byCode[c]!)
        .toList();
    _cache = ordered;
    return ordered;
  }

  static void clearCache() => _cache = null;
}
