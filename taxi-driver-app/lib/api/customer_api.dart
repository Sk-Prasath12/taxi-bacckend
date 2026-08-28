import 'package:taxiapp/api/api_client.dart';
import 'package:taxiapp/api/api_constants.dart';

class CustomerApi {
  final ApiClient client;

  CustomerApi({required this.client});

  factory CustomerApi.withToken(String? token) => CustomerApi(client: ApiClient(authToken: token));

  Future<Map<String, dynamic>?> login({required String email, required String password}) async {
    final result = await client.postJson(
      '${ApiConstants.customerBase}/login',
      body: {'email': email, 'password': password},
    );
    return result is Map<String, dynamic> ? result : null;
  }

  Future<List<Map<String, dynamic>>> getVehicleTypes() async {
    final result = await client.getJson('${ApiConstants.apiRestBase}/vehicle-types');
    if (result is List) {
      return result.whereType<Map<String, dynamic>>().map(_vehicle).toList();
    }
    if (result is Map<String, dynamic> && result['data'] is List) {
      return (result['data'] as List).whereType<Map<String, dynamic>>().map(_vehicle).toList();
    }
    return [];
  }

  Map<String, dynamic> _vehicle(Map<String, dynamic> v) => {
        'id': (v['id'] ?? v['_id']).toString(),
        'name': v['name']?.toString() ?? 'Vehicle',
      };

  Future<Map<String, dynamic>?> requestRide({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropLat,
    required double dropLng,
    required String dropAddress,
    required String vehicleTypeId,
    String paymentMode = 'CASH',
    String? paymentMethod,
  }) async {
    final result = await client.postJson(
      '${ApiConstants.customerBase}/rides/request',
      body: {
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'pickup_address': pickupAddress,
        'drop_lat': dropLat,
        'drop_lng': dropLng,
        'drop_address': dropAddress,
        'vehicle_type_id': vehicleTypeId,
        'payment_mode': paymentMode,
        if (paymentMethod != null) 'payment_method': paymentMethod,
      },
    );
    return result is Map<String, dynamic> ? result : null;
  }

  Future<Map<String, dynamic>?> confirmRide(String rideId, {String? paymentMode, String? paymentMethod}) async {
    final result = await client.postJson(
      '${ApiConstants.customerBase}/rides/confirm',
      body: {
        'ride_id': rideId,
        if (paymentMode != null) 'payment_mode': paymentMode,
        if (paymentMethod != null) 'payment_method': paymentMethod,
      },
    );
    return result is Map<String, dynamic> ? result : null;
  }

  /// Clears any open ride on the server so a new booking can start (not used to resume UI).
  Future<void> abandonStaleActiveRide() async {
    await client.postJson('${ApiConstants.customerBase}/rides/active/abandon');
  }

  Future<bool> cancelRide(String rideId) async {
    final result = await client.postJson('${ApiConstants.customerBase}/rides/$rideId/cancel');
    return result is Map<String, dynamic> && result['message'] != null;
  }

  Future<Map<String, dynamic>?> getRideStatus(String rideId) async {
    final result = await client.getJson('${ApiConstants.customerBase}/rides/$rideId/status');
    if (result is Map<String, dynamic>) {
      if (result['ride'] is Map<String, dynamic>) return result['ride'] as Map<String, dynamic>;
      return result;
    }
    return null;
  }

  Future<Map<String, dynamic>?> createPaymentOrder(String rideId) async {
    final result = await client.postJson(
      '${ApiConstants.apiRestBase}/payments/create-order',
      body: {'ride_id': rideId},
    );
    return result is Map<String, dynamic> ? result : null;
  }

  Future<bool?> verifyPayment({
    required String rideId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final result = await client.postJson(
      '${ApiConstants.apiRestBase}/payments/verify',
      body: {
        'ride_id': rideId,
        'order_id': orderId,
        'payment_id': paymentId,
        'signature': signature,
      },
    );
    if (result is Map<String, dynamic>) return result['success'] == true;
    return null;
  }

  Future<List<Map<String, dynamic>>> getRideHistory() async {
    final result = await client.getJson('${ApiConstants.customerBase}/rides/history');
    if (result is Map<String, dynamic>) {
      final data = result['rides'] ?? result['data'];
      if (data is List) {
        return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return [];
  }

  Future<Map<String, dynamic>?> getActiveRide() async {
    final result = await client.getJson('${ApiConstants.customerBase}/rides/active');
    if (result is Map<String, dynamic>) {
      if (result['ride'] is Map<String, dynamic>) return result['ride'] as Map<String, dynamic>;
      if (result['ride_id'] != null) return result;
    }
    return null;
  }
}
