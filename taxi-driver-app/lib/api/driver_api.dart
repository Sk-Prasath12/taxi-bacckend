import 'dart:typed_data';

import 'package:taxiapp/api/api_client.dart';
import 'package:taxiapp/api/api_constants.dart';
import 'package:taxiapp/api/api_result.dart';
import 'package:taxiapp/utils/ride_navigation_utils.dart';

class DriverDocumentsResult {
  final List<Map<String, dynamic>> documents;
  final String? error;

  const DriverDocumentsResult({required this.documents, this.error});
}

class DriverDocumentUploadResult {
  final Map<String, dynamic>? document;
  final String? error;

  const DriverDocumentUploadResult({this.document, this.error});
}

class DriverApi {
  final ApiClient client;

  DriverApi({required this.client});

  factory DriverApi.withToken(String? token) {
    return DriverApi(client: ApiClient(authToken: token));
  }

  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    final result = await client.postJson('${ApiConstants.driverBase}/login',
        body: {'email': email, 'password': password});
    if (result is Map<String, dynamic>) {
      return result;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDriverProfile() async {
    final result = await client.getJson('${ApiConstants.driverBase}/profile');
    if (result is Map<String, dynamic>) {
      return result;
    }
    return null;
  }

  Future<Map<String, dynamic>?> createOrUpdateDriverProfile(
      Map<String, dynamic> profileData) async {
    final result = await client.postJson('${ApiConstants.v1DriverBase}/profile',
        body: profileData);
    if (result is Map<String, dynamic>) {
      return result;
    }
    return null;
  }

  Future<({List<Map<String, dynamic>> rides, String? errorMessage})> fetchIncomingRides({
    double? lat,
    double? lng,
  }) async {
    final query = <String, String>{};
    if (lat != null && lng != null) {
      query['lat'] = lat.toString();
      query['lng'] = lng.toString();
    }
    final uri = Uri.parse('${ApiConstants.driverBase}/rides/incoming')
        .replace(queryParameters: query.isEmpty ? null : query);
    final result = await client.getResult(uri.toString());
    if (!result.success) {
      return (
        rides: <Map<String, dynamic>>[],
        errorMessage: result.message ?? 'Cannot load rides (status ${result.statusCode})',
      );
    }
    final body = result.data;
    if (body is Map<String, dynamic>) {
      final data = body['rides'] ?? body['data'];
      if (data is List) {
        return (rides: _normalizeRideList(data), errorMessage: null);
      }
    }
    if (body is List) {
      return (rides: _normalizeRideList(body), errorMessage: null);
    }
    return (rides: <Map<String, dynamic>>[], errorMessage: null);
  }

  Future<List<Map<String, dynamic>>> getIncomingRides() async {
    final result = await fetchIncomingRides();
    return result.rides;
  }

  Future<Map<String, dynamic>?> getWallet() async {
    final result = await client.getJson('${ApiConstants.driverBase}/wallet');
    if (result is Map<String, dynamic>) {
      return result;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getInvoice(String rideId) async {
    final result =
        await client.getJson('${ApiConstants.driverInvoiceBase}/invoices/$rideId');
    if (result is Map<String, dynamic>) {
      return result;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCashEarnings() async {
    final result =
        await client.getJson('${ApiConstants.driverBase}/earnings/cash');
    if (result is Map<String, dynamic>) {
      return result;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getTotalEarnings() async {
    final result =
        await client.getJson('${ApiConstants.driverBase}/earnings/total');
    if (result is Map<String, dynamic>) {
      return result;
    }
    return null;
  }

  /// period: today | week | month | year
  Future<Map<String, dynamic>?> getEarningsSummary(String period) async {
    final tz = DateTime.now().timeZoneOffset.inMinutes;
    final result = await client.getJson(
      '${ApiConstants.driverBase}/earnings/summary?period=$period&tz_offset=$tz',
    );
    if (result is Map<String, dynamic>) {
      return result;
    }
    return null;
  }

  Future<Map<String, dynamic>?> withdraw(double amount) async {
    final result = await client.postJson(
      '${ApiConstants.driverInvoiceBase}/wallet/withdraw',
      body: {'amount': amount},
    );
    if (result is Map<String, dynamic>) {
      return result;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getRideHistory() async {
    final result = await client.getJson('${ApiConstants.driverBase}/rides/history');
    if (result is Map<String, dynamic>) {
      final data = result['rides'] ?? result['data'];
      if (data is List) {
        return _normalizeRideList(data);
      }
    }
    if (result is List) {
      return _normalizeRideList(result);
    }
    return [];
  }

  Future<Map<String, dynamic>?> fetchActiveRide() async {
    final result = await client.getResult('${ApiConstants.driverBase}/rides/active');
    if (!result.success) return null;
    final body = result.data;
    if (body is Map<String, dynamic>) {
      final ride = body['ride'];
      if (ride is Map<String, dynamic>) {
        final normalized = RideNavigationUtils.ensureCoordinates(
          Map<String, dynamic>.from(ride),
        );
        final id = (normalized['ride_id'] ??
                normalized['rideId'] ??
                normalized['id'] ??
                '')
            .toString();
        if (id.isNotEmpty) {
          normalized['id'] = id;
          normalized['ride_id'] = id;
        }
        return normalized;
      }
    }
    return null;
  }

  Future<bool> acceptRide(String rideId) async {
    final result = await acceptRideResult(rideId);
    return result.success;
  }

  Future<({bool success, String? message, Map<String, dynamic>? ride})> acceptRideResult(
    String rideId,
  ) async {
    final response = await client.post(
      '${ApiConstants.driverBase}/rides/$rideId/accept',
    );
    final body = client.decode(response);
    Map<String, dynamic>? resultMap;
    if (body is Map<String, dynamic>) {
      resultMap = body;
    } else if (body is Map) {
      resultMap = Map<String, dynamic>.from(body);
    }
    final success = response.statusCode >= 200 &&
        response.statusCode < 300 &&
        (resultMap != null ? _isSuccess(resultMap) : false);
    final rideRaw = resultMap?['ride'];
    Map<String, dynamic>? ride;
    if (rideRaw is Map) {
      ride = RideNavigationUtils.ensureCoordinates(Map<String, dynamic>.from(rideRaw));
      final id = (ride['rideId'] ?? ride['ride_id'] ?? ride['id'] ?? rideId).toString();
      ride['id'] = id;
      ride['ride_id'] = id;
    }
    final message = resultMap?['message']?.toString();
    if (!success && message == null && response.statusCode == 409) {
      return (success: false, message: 'Ride no longer available.', ride: null);
    }
    return (success: success, message: message, ride: ride);
  }

  Future<({bool success, String? message})> rejectRideResult(String rideId) async {
    final response = await client.post(
      '${ApiConstants.driverBase}/rides/$rideId/reject',
    );
    final body = client.decode(response);
    Map<String, dynamic>? resultMap;
    if (body is Map<String, dynamic>) {
      resultMap = body;
    } else if (body is Map) {
      resultMap = Map<String, dynamic>.from(body);
    }
    final success = response.statusCode >= 200 &&
        response.statusCode < 300 &&
        (resultMap != null ? _isSuccess(resultMap) : false);
    return (
      success: success,
      message: resultMap?['message']?.toString(),
    );
  }

  Future<Map<String, dynamic>?> getRideById(String rideId) async {
    final result = await client.getJson('${ApiConstants.driverBase}/rides/$rideId');
    if (result is Map<String, dynamic>) {
      final data = result['data'] is Map ? Map<String, dynamic>.from(result['data'] as Map) : result;
      if (data['ride'] is Map) {
        return RideNavigationUtils.ensureCoordinates(
          Map<String, dynamic>.from(data['ride'] as Map),
        );
      }
      return RideNavigationUtils.ensureCoordinates(data);
    }
    return null;
  }

  Future<ApiResult> markArrivedResult(String rideId) async {
    final response = await client.post('${ApiConstants.driverBase}/rides/$rideId/arrived');
    return ApiResult.fromResponse(response.statusCode, client.decode(response));
  }

  Future<bool> markArrived(String rideId) async {
    final result = await markArrivedResult(rideId);
    return result.success || _isIdempotentRideStep(result, 'ARRIVED');
  }

  Future<ApiResult> verifyRideOtpResult(String rideId, String otp) async {
    final trimmed = otp.trim();
    final parsed = int.tryParse(trimmed);
    if (parsed == null) {
      return const ApiResult(
        statusCode: 400,
        success: false,
        message: 'Enter the numeric pickup OTP from the customer app',
      );
    }
    final response = await client.post(
      '${ApiConstants.driverBase}/rides/$rideId/verify-otp',
      body: {'otp': parsed},
    );
    return ApiResult.fromResponse(response.statusCode, client.decode(response));
  }

  Future<bool> verifyRideOtp(String rideId, String otp) async {
    final result = await verifyRideOtpResult(rideId, otp);
    return result.success ||
        (result.message ?? '').toLowerCase().contains('already verified');
  }

  Future<bool> markPickedUp(String rideId) async {
    final result = await markPickedUpResult(rideId);
    return result.success;
  }

  Future<ApiResult> markPickedUpResult(String rideId) async {
    final response = await client.post(
      '${ApiConstants.driverBase}/rides/$rideId/picked-up',
    );
    return ApiResult.fromResponse(response.statusCode, client.decode(response));
  }

  Future<bool> markInTransit(String rideId) async {
    final result = await markInTransitResult(rideId);
    return result.success;
  }

  Future<ApiResult> markInTransitResult(String rideId) async {
    final response = await client.post(
      '${ApiConstants.driverBase}/rides/$rideId/in-transit',
    );
    return ApiResult.fromResponse(response.statusCode, client.decode(response));
  }

  /// Picked-up + in-transit; tolerates already-started rides (avoids duplicate-tap errors).
  Future<ApiResult> startTripResult(String rideId, {String? currentStatus}) async {
    final s = (currentStatus ?? '').toUpperCase();
    if (s == 'IN_TRANSIT') {
      return const ApiResult(statusCode: 200, success: true, message: 'Trip already in progress');
    }
    ApiResult? pickResult;
    if (s != 'PICKED_UP') {
      pickResult = await markPickedUpResult(rideId);
      if (!pickResult.success && !_isIdempotentRideStep(pickResult, 'PICKED_UP')) {
        return pickResult;
      }
    }
    final transitResult = await markInTransitResult(rideId);
    if (transitResult.success || _isIdempotentRideStep(transitResult, 'IN_TRANSIT')) {
      return ApiResult(
        statusCode: transitResult.statusCode,
        success: true,
        message: transitResult.message ?? pickResult?.message ?? 'Trip started',
        data: transitResult.data,
      );
    }
    return transitResult;
  }

  bool _isIdempotentRideStep(ApiResult result, String expectedStatus) {
    if (result.success) return true;
    final msg = (result.message ?? '').toLowerCase();
    final status = (result.data is Map
            ? (result.data as Map)['status']?.toString()
            : null)
        ?.toUpperCase();
    if (status == expectedStatus) return true;
    return msg.contains('already') ||
        msg.contains('in transit') ||
        msg.contains('picked') ||
        msg.contains('started') ||
        msg.contains('arrived');
  }

  Future<bool> markDropped(
    String rideId, {
    double? fare,
    double? lat,
    double? lng,
    double? actualDistanceKm,
    double? durationMin,
  }) async {
    final result = await markDroppedResult(
      rideId,
      fare: fare,
      lat: lat,
      lng: lng,
      actualDistanceKm: actualDistanceKm,
      durationMin: durationMin,
    );
    return result.success;
  }

  Future<ApiResult> markDroppedResult(
    String rideId, {
    double? fare,
    double? lat,
    double? lng,
    double? actualDistanceKm,
    double? durationMin,
  }) async {
    final body = <String, dynamic>{};
    if (fare != null) body['fare'] = fare;
    if (lat != null) body['lat'] = lat;
    if (lng != null) body['lng'] = lng;
    if (actualDistanceKm != null) body['actual_distance_km'] = actualDistanceKm;
    if (durationMin != null) body['duration_min'] = durationMin;
    final response = await client.post(
      '${ApiConstants.driverBase}/rides/$rideId/dropped',
      body: body.isEmpty ? null : body,
    );
    return ApiResult.fromResponse(response.statusCode, client.decode(response));
  }

  Future<bool> verifyDropOtp(String rideId, String otp) async {
    final result = await verifyDropOtpResult(rideId, otp);
    return result.success;
  }

  Future<ApiResult> verifyDropOtpResult(String rideId, String otp) async {
    final otpValue = int.tryParse(otp) ?? otp;
    final response = await client.post(
      '${ApiConstants.driverBase}/rides/$rideId/verify-drop-otp',
      body: {'otp': otpValue},
    );
    return ApiResult.fromResponse(response.statusCode, client.decode(response));
  }

  Future<ApiResult> confirmCashReceivedResult(String rideId) async {
    final response = await client.post(
      '${ApiConstants.driverBase}/rides/$rideId/cash-received',
    );
    return ApiResult.fromResponse(response.statusCode, client.decode(response));
  }

  Future<bool> confirmCashReceived(String rideId) async {
    final result = await confirmCashReceivedResult(rideId);
    return result.success || _isSuccess(result.data);
  }

  Future<ApiResult> completeRideResult(String rideId) async {
    final response = await client.post(
      '${ApiConstants.driverBase}/rides/$rideId/complete',
    );
    return ApiResult.fromResponse(response.statusCode, client.decode(response));
  }

  Future<bool> completeRide(String rideId) async {
    final result = await completeRideResult(rideId);
    return result.success ||
        (result.message ?? '').toLowerCase().contains('already completed') ||
        _isSuccess(result.data);
  }

  Future<bool> startRide(String rideId) async {
    final result =
        await client.postJson('${ApiConstants.driverBase}/rides/$rideId/start');
    return _isSuccess(result);
  }

  Future<bool> endRide(String rideId) async {
    final result =
        await client.postJson('${ApiConstants.driverBase}/rides/$rideId/end');
    return _isSuccess(result);
  }

  /// Latest ride row for payment/status refresh (active → direct → history).
  Future<Map<String, dynamic>?> findRideInHistory(String rideId) async {
    final direct = await getRide(rideId);
    if (direct != null) return direct;

    final active = await fetchActiveRide();
    if (active != null) {
      final id = (active['ride_id'] ?? active['id'] ?? '').toString();
      if (id == rideId) return active;
    }

    final history = await getRideHistory();
    for (final ride in history) {
      final id = (ride['ride_id'] ?? ride['id'] ?? '').toString();
      if (id == rideId) return ride;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getRide(String rideId) async {
    final result = await client.getResult('${ApiConstants.driverBase}/rides/$rideId');
    if (!result.success) return null;
    final body = result.data;
    if (body is Map<String, dynamic>) {
      final data = body['ride'] ?? body['data'] ?? body;
      if (data is Map<String, dynamic>) {
        return RideNavigationUtils.ensureCoordinates(
          Map<String, dynamic>.from(data)..['id'] = rideId,
        );
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> getActiveAssignedRide() async {
    final active = await fetchActiveRide();
    if (active != null) return active;

    const activeStatuses = {
      'DRIVER_ASSIGNED',
      'ARRIVED_AT_PICKUP',
      'ARRIVED',
      'STARTED',
      'PICKED_UP',
      'IN_TRANSIT',
      'ACCEPTED',
      'accepted',
      'arrived',
      'started',
      'DROPPED',
      'COMPLETED_PENDING_PAYMENT',
      'completed_pending_payment',
    };
    final history = await getRideHistory();
    for (final ride in history) {
      final status = (ride['status'] ?? '').toString().toUpperCase();
      if (activeStatuses.contains(status)) return ride;
    }
    return null;
  }

  Future<DriverDocumentsResult> listDocuments() async {
    final result = await client.getResult('${ApiConstants.driverBase}/documents');
    if (!result.success) {
      return DriverDocumentsResult(
        documents: const [],
        error: result.message ?? 'Failed to load documents',
      );
    }
    final body = result.data;
    if (body is Map<String, dynamic>) {
      final docs = body['documents'] ?? body['data'];
      if (docs is List) {
        return DriverDocumentsResult(
          documents: docs
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
      }
      // successResponse wraps a single document object in `data`
      if (docs is Map) {
        return DriverDocumentsResult(
          documents: [Map<String, dynamic>.from(docs)],
        );
      }
    }
    if (body is List) {
      return DriverDocumentsResult(
        documents: body
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );
    }
    return const DriverDocumentsResult(documents: []);
  }

  Future<void> submitDocumentsForReview() async {
    await client.postJson('${ApiConstants.driverBase}/documents/submit');
  }

  Future<DriverDocumentUploadResult> uploadDocument({
    required String documentType,
    required Uint8List bytes,
    required String filename,
    String? mimeType,
    String? documentSlot,
  }) async {
    try {
      final response = await client.postMultipart(
        '${ApiConstants.driverBase}/documents/upload',
        fieldName: 'file',
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
        query: {
          'document_type': documentType,
          if (documentSlot != null && documentSlot.isNotEmpty)
            'document_slot': documentSlot,
        },
      );
      final decoded = client.decode(response);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final message = decoded is Map
            ? (decoded['message'] ?? decoded['error'])?.toString()
            : null;
        return DriverDocumentUploadResult(
          error: message ?? 'Upload failed (${response.statusCode})',
        );
      }
      if (decoded is Map<String, dynamic>) {
        final doc = decoded['document'] ?? decoded['data'] ?? decoded;
        if (doc is Map<String, dynamic>) {
          return DriverDocumentUploadResult(document: doc);
        }
        if (doc is Map) {
          return DriverDocumentUploadResult(
            document: Map<String, dynamic>.from(doc),
          );
        }
      }
      return const DriverDocumentUploadResult(error: 'Invalid upload response');
    } catch (e) {
      return DriverDocumentUploadResult(error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> getRideRoute({
    required String rideId,
    required double currentLat,
    required double currentLng,
    required String stage,
  }) async {
    final result = await client.getJson(
      '${ApiConstants.driverBase}/rides/$rideId/route?currentLat=$currentLat&currentLng=$currentLng&stage=$stage',
    );
    if (result is Map<String, dynamic>) {
      return result;
    }
    return null;
  }

  List<Map<String, dynamic>> _normalizeRideList(List<dynamic> data) {
    return data.map<Map<String, dynamic>>((item) {
      if (item is Map<String, dynamic>) {
        final id = item['id'] ?? item['_id'] ?? item['rideId'] ?? item['ride_id'];
        final pickupMap = item['pickup'] is Map
            ? Map<String, dynamic>.from(item['pickup'] as Map)
            : null;
        final dropMap = item['drop'] is Map
            ? Map<String, dynamic>.from(item['drop'] as Map)
            : item['dropoff'] is Map
                ? Map<String, dynamic>.from(item['dropoff'] as Map)
                : null;
        final customerMap = item['customer'] is Map
            ? Map<String, dynamic>.from(item['customer'] as Map)
            : null;
        final customerName = item['customerName'] ??
            item['customer_name'] ??
            item['passengerName'] ??
            item['passenger_name'] ??
            item['user_name'] ??
            customerMap?['name'] ??
            'Passenger';
        final customerPhone = item['customer_phone'] ??
            item['customerPhone'] ??
            customerMap?['phone'];
        final normalized = <String, dynamic>{
          'id': id,
          'ride_id': id,
          'passengerName': customerName,
          'customerName': customerName,
          'customer_phone': customerPhone,
          'customer': customerMap,
          'pickup': pickupMap ??
              item['pickupAddress'] ??
              item['pickup_address'] ??
              item['pickup'] ??
              item['pickup_location'] ??
              'Unknown',
          'pickupAddress': item['pickupAddress'] ?? item['pickup_address'],
          'dropoff': dropMap ??
              item['dropAddress'] ??
              item['drop_address'] ??
              item['dropoff'] ??
              item['drop'] ??
              item['dropoff_location'] ??
              item['dropoff_address'] ??
              'Unknown',
          'dropAddress': item['dropAddress'] ?? item['drop_address'],
          'drop': dropMap ?? item['drop'],
          'distance': item['distance_km'] != null
              ? '${item['distance_km']} km'
              : item['distance'] != null
                  ? '${item['distance']}'
                  : '0',
          'duration': item['duration'] ?? item['eta'] ?? '15 min',
          'fare': (item['fare'] as num?)?.toDouble() ?? (item['price'] as num?)?.toDouble() ?? 0.0,
          'driverEarnings': (item['driverEarnings'] as num?)?.toDouble() ??
              (item['driver_earnings'] as num?)?.toDouble(),
          'paymentMethod': item['paymentMethod'] ?? item['payment_method'] ?? item['payment_mode'],
          'completedAt': item['completedAt'] ??
              item['completed_at'] ??
              (item['status']?.toString().toUpperCase() == 'COMPLETED'
                  ? (item['updatedAt'] ?? item['updated_at'])
                  : null),
          'duration_min': item['duration_min'] ?? item['actual_duration_min'],
          'actual_distance_km': item['actual_distance_km'],
          'status': item['status'] ?? 'pending',
          'time': item['completedAt'] ??
              item['completed_at'] ??
              item['updatedAt'] ??
              item['requested_at'] ??
              item['createdAt'] ??
              item['created_at'] ??
              DateTime.now().toIso8601String(),
          'pickupLat': (pickupMap?['lat'] as num?)?.toDouble() ??
              (item['pickup_lat'] as num?)?.toDouble() ??
              (item['pickupLocation']?['lat'] as num?)?.toDouble(),
          'pickupLng': (pickupMap?['lng'] as num?)?.toDouble() ??
              (item['pickup_lng'] as num?)?.toDouble() ??
              (item['pickupLocation']?['lng'] as num?)?.toDouble(),
          'dropLat': (dropMap?['lat'] as num?)?.toDouble() ??
              (item['drop_lat'] as num?)?.toDouble() ??
              (item['dropoffLocation']?['lat'] as num?)?.toDouble(),
          'dropLng': (dropMap?['lng'] as num?)?.toDouble() ??
              (item['drop_lng'] as num?)?.toDouble() ??
              (item['dropoffLocation']?['lng'] as num?)?.toDouble(),
          'drop_reached': item['drop_reached'],
          'drop_otp': item['drop_otp'],
          'drop_otp_verified': item['drop_otp_verified'],
          'otp_verified': item['otp_verified'],
          'payment_status': item['payment_status'],
          'payment_mode': item['payment_mode'],
          'customer_name': item['customer_name'] ?? item['customerName'],
          'rating': (item['rating'] as num?)?.toDouble() ?? 0.0,
          'trips': item['trips'] ?? item['completed_trips'] ?? 0,
        };
        return RideNavigationUtils.ensureCoordinates(normalized);
      }
      return <String, dynamic>{};
    }).where((item) => item['id'] != null).toList();
  }

  bool _isSuccess(dynamic result) {
    if (result is Map<String, dynamic>) {
      if (result.containsKey('success')) {
        return result['success'] == true;
      }
      if (result.containsKey('ride') && result['ride'] is Map) return true;
      if (result.containsKey('ride_id')) return true;
      final msg = result['message']?.toString().toLowerCase() ?? '';
      if (msg.contains('success') || msg.contains('accepted') || msg.contains('updated')) {
        return true;
      }
      if (result.containsKey('status')) {
        final s = result['status'].toString().toUpperCase();
        return s == 'SUCCESS' ||
            s == 'OK' ||
            s == 'DRIVER_ASSIGNED' ||
            s == 'ARRIVED_AT_PICKUP' ||
            s == 'PICKED_UP' ||
            s == 'IN_TRANSIT' ||
            s == 'COMPLETED';
      }
      return true;
    }
    return false;
  }
}
