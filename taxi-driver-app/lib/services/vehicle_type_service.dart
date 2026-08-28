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

/// Canonical codes — must match backend `ensure-canonical-vehicles`.
const kCanonicalVehicleCodes = [
  'BIKE',
  'AUTO',
  'MINI',
  'SEDAN',
  'SUV',
  'PREMIUM_SEDAN',
  'PREMIUM_SUV',
  'XL',
  'ELECTRIC',
  'ACCESSIBLE',
];

const kCanonicalVehicleNames = [
  'Bike',
  'Auto',
  'Mini',
  'Sedan',
  'SUV',
  'Premium Sedan',
  'Premium SUV',
  'XL',
  'Electric',
  'Accessible',
];

String vehicleDisplayLabel(String backendName, {String? code}) {
  switch ((code ?? '').toUpperCase()) {
    case 'BIKE':
      return 'Bike';
    case 'AUTO':
      return 'Auto';
    case 'MINI':
      return 'Mini';
    case 'SEDAN':
    case 'CAR_5_SEATER':
      return 'Sedan';
    case 'SUV':
    case 'CAR_7_SEATER':
      return 'SUV';
    case 'PREMIUM_SEDAN':
      return 'Premium Sedan';
    case 'PREMIUM_SUV':
      return 'Premium SUV';
    case 'XL':
      return 'XL';
    case 'ELECTRIC':
      return 'Electric';
    case 'ACCESSIBLE':
      return 'Accessible';
  }
  switch (backendName) {
    case 'Small 5 Seater Car':
    case '5 Seater':
      return 'Sedan';
    case 'Big 7 Seater Car':
    case '7 Seater':
      return 'SUV';
    default:
      return backendName;
  }
}

String? _normalizeCode(String? code, String name) {
  final c = (code ?? '').trim().toUpperCase();
  if (kCanonicalVehicleCodes.contains(c)) return c;
  // Legacy aliases
  if (c == 'CAR_5_SEATER' || c == '5_SEATER') return 'SEDAN';
  if (c == 'CAR_7_SEATER' || c == '7_SEATER') return 'SUV';
  final n = name.trim().toLowerCase();
  if (n == 'bike' || n.contains('bike') || n.contains('motor')) return 'BIKE';
  if (n == 'auto' || n.contains('auto')) return 'AUTO';
  if (n == 'mini' || n.contains('hatch')) return 'MINI';
  if (n.contains('premium sedan') || n.contains('luxury')) return 'PREMIUM_SEDAN';
  if (n.contains('premium suv')) return 'PREMIUM_SUV';
  if (n == 'sedan' || n.contains('5 seater')) return 'SEDAN';
  if (n == 'suv' || n.contains('7 seater')) return 'SUV';
  if (n == 'xl' || n.contains('van')) return 'XL';
  if (n.contains('electric') || n.contains('hybrid') || n == 'ev') return 'ELECTRIC';
  if (n.contains('access') || n.contains('wheelchair')) return 'ACCESSIBLE';
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
        : body is Map
            ? (body['data'] ?? body['vehicle_types'])
            : null;
    if (list is! List) return [];

    final byCode = <String, VehicleTypeOption>{};
    for (final raw in list) {
      if (raw is! Map) continue;
      final name = raw['name']?.toString() ?? '';
      final code = _normalizeCode(raw['code']?.toString(), name);
      if (code == null || !kCanonicalVehicleCodes.contains(code)) continue;
      final id = raw['id']?.toString() ?? raw['_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      byCode[code] = VehicleTypeOption(
        id: id,
        code: code,
        name: name,
        displayLabel: vehicleDisplayLabel(name, code: code),
        perKmRate: (raw['per_km_rate'] as num?)?.toDouble() ?? 0,
        maxPassengers: (raw['max_passengers'] as num?)?.toInt() ?? 1,
      );
    }

    final options = kCanonicalVehicleCodes
        .where(byCode.containsKey)
        .map((c) => byCode[c]!)
        .toList();
    _cache = options;
    return options;
  }
}
