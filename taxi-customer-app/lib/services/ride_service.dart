import 'dart:convert';

import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../domain/services/auth_storage.dart';
import '../models/ride_models.dart';
import 'active_ride_store.dart';
import 'customer_auth_manager.dart';
import 'customer_session_store.dart';
import 'session_service.dart';
import '../utils/location_logger.dart';
import 'vehicle_types_cache.dart';

class RideService {
  static const Duration _apiTimeout = Duration(seconds: 12);
  static String? lastVehicleLoadError;
  static bool lastVehicleLoadUsedCache = false;

  static void _logUrl(Uri url) {
    print('Calling API: $url');
  }

  static Future<String> _token() async {
    final token = await CustomerSessionStore.getAccessToken() ??
        await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('User not authenticated');
    }
    return token;
  }

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static String _messageFromBody(String body,
      {String fallback = 'Request failed'}) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.isNotEmpty) {
          return _friendlyRideMessage(message);
        }
      }
    } catch (_) {}
    return fallback;
  }

  static String _friendlyRideMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('pickup zone inactive')) {
      return 'Pickup location is outside our service area. Move the pin or contact support.';
    }
    if (lower.contains('drop zone inactive')) {
      return 'Drop location is outside our service area. Choose a destination within Tamil Nadu.';
    }
    return raw;
  }

  static Future<void> _handleUnauthorized() async {
    final refreshed = await CustomerAuthManager.refreshAccessToken();
    if (refreshed) return;
    await CustomerAuthManager.logout();
    SessionService.redirectToLogin();
  }

  /// Returns the customer's in-progress ride, or null if none.
  static Future<Map<String, dynamic>?> getActiveRide() async {
    try {
      final token = await _token();
      final url = Uri.parse('${ApiConfig.baseUrl}/customers/rides/active');
      _logUrl(url);
      final response =
          await http.get(url, headers: _headers(token)).timeout(_apiTimeout);
      if (response.statusCode == 401) {
        if (await CustomerAuthManager.refreshAccessToken()) {
          return getActiveRide();
        }
        await CustomerAuthManager.logout();
        SessionService.redirectToLogin();
        return null;
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;

      // Support flat payload or nested { ride } / { data: { ride } } / { data }.
      Map<String, dynamic> rideMap;
      if (data['ride_id'] != null || data['id'] != null) {
        rideMap = data;
      } else if (data['ride'] is Map) {
        rideMap = Map<String, dynamic>.from(data['ride'] as Map);
      } else if (data['data'] is Map) {
        final nested = Map<String, dynamic>.from(data['data'] as Map);
        if (nested['ride'] is Map) {
          rideMap = Map<String, dynamic>.from(nested['ride'] as Map);
        } else {
          rideMap = nested;
        }
      } else {
        // e.g. { message: "No active ride" }
        await ActiveRideStore.clear();
        return null;
      }

      final rideId = (rideMap['ride_id'] ?? rideMap['id'] ?? '').toString();
      if (rideId.isEmpty) {
        await ActiveRideStore.clear();
        return null;
      }

      final status = (rideMap['status'] ?? '').toString().toUpperCase();
      if (status == 'CANCELLED' || status == 'CANCELLED_BY_CUSTOMER') {
        await ActiveRideStore.clear();
        return null;
      }
      if (status == 'COMPLETED') {
        final paymentStatus =
            (rideMap['payment_status'] ?? '').toString().toUpperCase();
        // Keep unpaid completed rides so payment screen can resume (cash or online).
        if (paymentStatus == 'PENDING' || paymentStatus.isEmpty) {
          await cacheActiveRide(rideMap);
          return rideMap;
        }
        await ActiveRideStore.clear();
        return null;
      }
      await cacheActiveRide(rideMap);
      return rideMap;
    } catch (e) {
      print('getActiveRide: $e');
      final cached = await ActiveRideStore.load();
      if (cached == null) return null;
      final status = (cached['status'] ?? '').toString().toUpperCase();
      if (status == 'CANCELLED' || status == 'CANCELLED_BY_CUSTOMER') {
        await ActiveRideStore.clear();
        return null;
      }
      return cached;
    }
  }

  static Future<void> cacheActiveRide(Map<String, dynamic> ride) async {
    final rideId = (ride['ride_id'] ?? ride['id'] ?? '').toString();
    if (rideId.isEmpty) return;
    await ActiveRideStore.save(rideId: rideId, payload: ride);
  }

  static Future<List<dynamic>> getRideHistory() async {
    try {
      final token = await _token();
      final url = Uri.parse('${ApiConfig.baseUrl}/customers/rides/history');
      _logUrl(url);
      final response = await http.get(url, headers: _headers(token)).timeout(_apiTimeout);
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw Exception('Access token expired - log in again');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final rides = data['rides'];
          if (rides is List<dynamic>) return rides;
        }
        return <dynamic>[];
      }
      throw Exception(_messageFromBody(response.body,
          fallback: 'Failed to fetch ride history'));
    } catch (e) {
      print('Network Error: $e');
      rethrow;
    }
  }

  static const List<String> customerVehicleOrder = [
    'Bike',
    'Auto',
    '5 Seater',
    '7 Seater',
  ];

  static const List<String> customerVehicleCodes = [
    'BIKE',
    'AUTO',
    'FIVE_SEATER',
    'SEVEN_SEATER',
  ];

  static const Map<String, String> _vehicleNameAliases = {
    'Small 5 Seater Car': '5 Seater',
    '5 Seater': '5 Seater',
    'Big 7 Seater Car': '7 Seater',
    '7 Seater': '7 Seater',
    'Motorbike': 'Bike',
    'Two Wheeler': 'Bike',
    'Hatchback': '5 Seater',
    'Mini': '5 Seater',
    'Sedan': '5 Seater',
    'SUV': '7 Seater',
    'Premium Sedan': '5 Seater',
    'Premium SUV': '7 Seater',
    'XL': '7 Seater',
    'Electric': '5 Seater',
    'Accessible': '5 Seater',
    'Luxury': '5 Seater',
    'Van': '7 Seater',
    'Hybrid': '5 Seater',
  };

  static String _normalizeVehicleName(String name) =>
      _vehicleNameAliases[name] ?? name;

  static List<VehicleTypeModel> _filterCustomerVehicles(
      List<VehicleTypeModel> list) {
    final canonicalNames = customerVehicleOrder.toSet();
    final canonicalCodes = customerVehicleCodes.toSet();
    final filtered = list.where((v) {
      final normalized = _normalizeVehicleName(v.name);
      final code = v.code?.toUpperCase();
      return canonicalNames.contains(normalized) ||
          canonicalNames.contains(v.name) ||
          (code != null && canonicalCodes.contains(code));
    }).map((v) {
      final normalized = _normalizeVehicleName(v.name);
      if (normalized != v.name) {
        return v.copyWith(name: normalized);
      }
      return v;
    }).toList();
    filtered.sort((a, b) {
      final ai = customerVehicleOrder.indexOf(a.name);
      final bi = customerVehicleOrder.indexOf(b.name);
      final ac = a.code != null ? customerVehicleCodes.indexOf(a.code!.toUpperCase()) : -1;
      final bc = b.code != null ? customerVehicleCodes.indexOf(b.code!.toUpperCase()) : -1;
      final aOrder = ai >= 0 ? ai : (ac >= 0 ? ac : 99);
      final bOrder = bi >= 0 ? bi : (bc >= 0 ? bc : 99);
      return aOrder.compareTo(bOrder);
    });
    return filtered;
  }

  /// Accept catalogs that include the four production vehicle types.
  static bool _isCompleteCatalog(List<VehicleTypeModel> list) {
    if (list.isEmpty) return false;
    final codes = list
        .map((v) => v.code?.toUpperCase())
        .whereType<String>()
        .toSet();
    if (codes.isEmpty) {
      final names = list.map((v) => _normalizeVehicleName(v.name)).toSet();
      return customerVehicleOrder.every(names.contains);
    }
    return customerVehicleCodes.every(codes.contains) ||
        list.length >= customerVehicleCodes.length;
  }

  /// Last-resort display names only — IDs must come from live API / cache.
  static List<VehicleTypeModel> get _builtInVehicles => const [];

  static Future<List<VehicleTypeModel>> getVehicleTypes({
    bool allowCacheFallback = true,
  }) async {
    lastVehicleLoadError = null;
    lastVehicleLoadUsedCache = false;
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/vehicle-types/active');
      _logUrl(url);
      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(_apiTimeout);
      if (response.statusCode != 200) {
        throw Exception(_messageFromBody(response.body,
            fallback: 'Failed to load vehicle types (${response.statusCode})'));
      }
      final data = jsonDecode(response.body);
      List<VehicleTypeModel> parsed = <VehicleTypeModel>[];
      if (data is Map<String, dynamic>) {
        final rawList = data['vehicle_types'] ?? data['data'] ?? data['value'];
        if (rawList is List) {
          parsed = rawList
              .whereType<Map>()
              .map((e) => VehicleTypeModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      } else if (data is List) {
        parsed = data
            .whereType<Map>()
            .map((e) => VehicleTypeModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      var filtered = _filterCustomerVehicles(parsed);
      // Never show non-canonical types (only Bike / Auto / 5 Seater / 7 Seater).
      if (filtered.isEmpty) {
        throw Exception('No vehicle types configured on server');
      }
      // Prefer complete catalog; clear stale incomplete cache.
      if (!_isCompleteCatalog(filtered)) {
        await VehicleTypesCache.clear();
      }
      await VehicleTypesCache.save(filtered);
      return filtered;
    } catch (e) {
      print('Network Error: $e');
      lastVehicleLoadError = e.toString();
      if (allowCacheFallback) {
        final cached = await VehicleTypesCache.load();
        final filtered = _filterCustomerVehicles(cached);
        if (filtered.isNotEmpty && _isCompleteCatalog(filtered)) {
          lastVehicleLoadUsedCache = true;
          return filtered;
        }
        if (filtered.isNotEmpty) {
          // Incomplete/stale catalog — do not book against old vehicle IDs.
          await VehicleTypesCache.clear();
        }
        lastVehicleLoadUsedCache = true;
        return _builtInVehicles;
      }
      rethrow;
    }
  }

  /// Cancels any open ride on the server so a new booking can be created.
  static Future<bool> abandonStaleActiveRide() async {
    try {
      final token = await _token();
      final url =
          Uri.parse('${ApiConfig.baseUrl}/customers/rides/active/abandon');
      _logUrl(url);
      final response = await http.post(url, headers: _headers(token)).timeout(_apiTimeout);
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return false;
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        print(
            'abandonStaleActiveRide HTTP ${response.statusCode}: ${response.body}');
        return false;
      }
      await ActiveRideStore.clear();
      await SessionService.clearRide();
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data['cleared'] == true;
      }
      return true;
    } catch (e) {
      print('abandonStaleActiveRide: $e');
      return false;
    }
  }

  static void _validateCoordinate(double lat, double lng, String label) {
    if (!lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      throw Exception('Invalid $label coordinates');
    }
    if (lat == 0 && lng == 0) {
      throw Exception('$label location is not set — enable GPS or pick on map');
    }
  }

  static Future<RideSnapshot> createRide({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
    required String pickupAddress,
    required String dropAddress,
    required String vehicleTypeId,
    required String paymentMode,
  }) async {
    _validateCoordinate(pickupLat, pickupLng, 'pickup');
    _validateCoordinate(dropLat, dropLng, 'drop');
    final payload = {
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'pickup_address': pickupAddress,
      'drop_lat': dropLat,
      'drop_lng': dropLng,
      'drop_address': dropAddress,
      'vehicle_type_id': vehicleTypeId,
      'payment_mode': paymentMode,
    };
    LocationLogger.booking(
      'createRide request',
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      pickupAddress: pickupAddress,
      dropLat: dropLat,
      dropLng: dropLng,
      dropAddress: dropAddress,
    );
    LocationLogger.api('POST /customers/rides/request', payload: payload);
    final body = jsonEncode(payload);

    try {
      final token = await _token();
      final url = Uri.parse('${ApiConfig.baseUrl}/customers/rides/request');
      _logUrl(url);

      await abandonStaleActiveRide();

      for (var attempt = 0; attempt < 3; attempt++) {
        final response =
            await http.post(url, headers: _headers(token), body: body).timeout(_apiTimeout);
        if (response.statusCode == 401) {
          await _handleUnauthorized();
          throw Exception('Access token expired - log in again');
        }
        if (response.statusCode == 200 || response.statusCode == 201) {
          return RideSnapshot.fromJson(jsonDecode(response.body));
        }
        if (response.statusCode == 409) {
          await abandonStaleActiveRide();
          continue;
        }
        throw Exception(
            _messageFromBody(response.body, fallback: 'Failed to create ride'));
      }

      throw Exception(
        'Could not start a new ride. Restart the backend server, then try Book Ride again.',
      );
    } catch (e) {
      print('Network Error: $e');
      rethrow;
    }
  }

  static Future<RideSnapshot> confirmRide({
    required String rideId,
    required String paymentMode,
  }) async {
    try {
      final token = await _token();
      final url = Uri.parse('${ApiConfig.baseUrl}/customers/rides/confirm');
      _logUrl(url);
      final response = await http.post(
        url,
        headers: _headers(token),
        body: jsonEncode({
          'ride_id': rideId,
          'payment_mode': paymentMode,
        }),
      ).timeout(_apiTimeout);
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw Exception('Access token expired - log in again');
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_messageFromBody(response.body,
            fallback: 'Failed to confirm ride'));
      }
      return RideSnapshot.fromJson(jsonDecode(response.body));
    } catch (e) {
      print('Network Error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getRideStatus(String rideId) async {
    try {
      final token = await _token();
      final url =
          Uri.parse('${ApiConfig.baseUrl}/customers/rides/$rideId/status');
      _logUrl(url);
      final response = await http.get(url, headers: _headers(token)).timeout(_apiTimeout);
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw Exception('Access token expired - log in again');
      }
      if (response.statusCode != 200) {
        throw Exception(_messageFromBody(response.body,
            fallback: 'Failed to get ride status'));
      }
      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } catch (e) {
      print('Network Error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getRideById(String rideId) async {
    try {
      final token = await _token();
      final url =
          Uri.parse('${ApiConfig.baseUrl}/customers/rides/$rideId/status');
      _logUrl(url);
      final response = await http.get(url, headers: _headers(token)).timeout(_apiTimeout);
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw Exception('Access token expired - log in again');
      }
      if (response.statusCode != 200) {
        throw Exception(
            _messageFromBody(response.body, fallback: 'Failed to fetch ride'));
      }
      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } catch (e) {
      print('Network Error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getRideHistoryDetails(
      String rideId) async {
    try {
      final token = await _token();
      final url =
          Uri.parse('${ApiConfig.baseUrl}/customers/rides/history/$rideId');
      _logUrl(url);
      final response = await http.get(url, headers: _headers(token)).timeout(_apiTimeout);
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw Exception('Access token expired - log in again');
      }
      if (response.statusCode != 200) {
        throw Exception(_messageFromBody(response.body,
            fallback: 'Failed to fetch ride details'));
      }
      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } catch (e) {
      print('Network Error: $e');
      rethrow;
    }
  }

  static Future<void> cancelRide(String rideId, {String? reason}) async {
    try {
      final token = await _token();
      final url =
          Uri.parse('${ApiConfig.baseUrl}/customers/rides/$rideId/cancel');
      _logUrl(url);
      final response = await http
          .post(
            url,
            headers: {
              ..._headers(token),
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              if (reason != null && reason.trim().isNotEmpty)
                'reason': reason.trim(),
            }),
          )
          .timeout(_apiTimeout);
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw Exception('Access token expired - log in again');
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
            _messageFromBody(response.body, fallback: 'Failed to cancel ride'));
      }
      await ActiveRideStore.clear();
      await SessionService.clearRide();
    } catch (e) {
      print('Network Error: $e');
      rethrow;
    }
  }

  static Future<void> triggerEmergency(
    String rideId, {
    double? lat,
    double? lng,
  }) async {
    final token = await _token();
    final url =
        Uri.parse('${ApiConfig.baseUrl}/customers/rides/$rideId/emergency');
    _logUrl(url);
    final response = await http
        .post(
          url,
          headers: _headers(token),
          body: jsonEncode({
            if (lat != null) 'lat': lat,
            if (lng != null) 'lng': lng,
          }),
        )
        .timeout(_apiTimeout);
    if (response.statusCode == 401) {
      await _handleUnauthorized();
      throw Exception('Access token expired - log in again');
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          _messageFromBody(response.body, fallback: 'Failed to send emergency alert'));
    }
  }

  static Future<PaymentOrder> createPaymentOrder(String rideId) async {
    try {
      final token = await _token();
      final url = Uri.parse('${ApiConfig.baseUrl}/payments/create-order');
      _logUrl(url);
      final response = await http.post(
        url,
        headers: _headers(token),
        body: jsonEncode({'ride_id': rideId}),
      ).timeout(_apiTimeout);
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw Exception('Access token expired - log in again');
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_messageFromBody(response.body,
            fallback: 'Failed to create payment order'));
      }
      return PaymentOrder.fromJson(jsonDecode(response.body));
    } catch (e) {
      print('Network Error: $e');
      rethrow;
    }
  }

  static Future<void> verifyPayment({
    required String rideId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final token = await _token();
      final url = Uri.parse('${ApiConfig.baseUrl}/payments/verify');
      _logUrl(url);
      final response = await http.post(
        url,
        headers: _headers(token),
        body: jsonEncode({
          'ride_id': rideId,
          'order_id': orderId,
          'payment_id': paymentId,
          'signature': signature,
        }),
      ).timeout(_apiTimeout);
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw Exception('Access token expired - log in again');
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_messageFromBody(response.body,
            fallback: 'Payment verification failed'));
      }
    } catch (e) {
      print('Network Error: $e');
      rethrow;
    }
  }

  static Future<InvoiceModel> getInvoice(String rideId) async {
    try {
      final token = await _token();
      final url =
          Uri.parse('${ApiConfig.baseUrl}/customers/rides/$rideId/invoice');
      _logUrl(url);
      final response = await http.get(url, headers: _headers(token)).timeout(_apiTimeout);
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw Exception('Access token expired - log in again');
      }
      if (response.statusCode != 200) {
        throw Exception(_messageFromBody(response.body,
            fallback: 'Failed to load invoice'));
      }
      return InvoiceModel.fromJson(jsonDecode(response.body));
    } catch (e) {
      print('Network Error: $e');
      rethrow;
    }
  }
}
