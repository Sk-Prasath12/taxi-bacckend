class VehicleTypeModel {
  final String id;
  final String name;
  final String? code;
  final int maxPassengers;
  final double perKmRate;

  const VehicleTypeModel({
    required this.id,
    required this.name,
    this.code,
    required this.maxPassengers,
    required this.perKmRate,
  });

  VehicleTypeModel copyWith({
    String? id,
    String? name,
    String? code,
    int? maxPassengers,
    double? perKmRate,
  }) {
    return VehicleTypeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      maxPassengers: maxPassengers ?? this.maxPassengers,
      perKmRate: perKmRate ?? this.perKmRate,
    );
  }

  factory VehicleTypeModel.fromJson(Map<String, dynamic> json) {
    return VehicleTypeModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? 'Taxi').toString(),
      code: json['code']?.toString(),
      maxPassengers: (json['max_passengers'] is num)
          ? (json['max_passengers'] as num).toInt()
          : 4,
      perKmRate: (json['per_km_rate'] is num)
          ? (json['per_km_rate'] as num).toDouble()
          : 0,
    );
  }
}

class RideSnapshot {
  final String rideId;
  final double distanceKm;
  final double durationMin;
  final double fare;
  final String status;
  final int? otp;
  final String? paymentMode;
  final String? paymentStatus;
  final String? driverName;

  const RideSnapshot({
    required this.rideId,
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    required this.status,
    this.otp,
    this.paymentMode,
    this.paymentStatus,
    this.driverName,
  });

  factory RideSnapshot.fromJson(Map<String, dynamic> json) {
    final unwrapped = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final ride = unwrapped['ride'] is Map<String, dynamic>
        ? unwrapped['ride'] as Map<String, dynamic>
        : unwrapped;
    final driver = ride['driver'] is Map<String, dynamic> ? ride['driver'] as Map<String, dynamic> : null;
    return RideSnapshot(
      rideId: (unwrapped['ride_id'] ?? ride['ride_id'] ?? '').toString(),
      distanceKm: ((unwrapped['distance_km'] ?? ride['distance_km'] ?? 0) as num).toDouble(),
      durationMin: ((unwrapped['duration_min'] ?? ride['duration_min'] ?? 0) as num).toDouble(),
      fare: ((unwrapped['fare'] ?? ride['fare'] ?? 0) as num).toDouble(),
      status: (unwrapped['status'] ?? ride['status'] ?? '').toString(),
      otp: (ride['otp'] ?? unwrapped['otp']) is num
          ? ((ride['otp'] ?? unwrapped['otp']) as num).toInt()
          : null,
      paymentMode: ride['payment_mode']?.toString(),
      paymentStatus: ride['payment_status']?.toString(),
      driverName: driver?['name']?.toString(),
    );
  }
}

class PaymentOrder {
  final String orderId;
  final int amount;
  final String currency;
  final String key;

  const PaymentOrder({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.key,
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return PaymentOrder(
      orderId: (data['order_id'] ?? data['orderId'] ?? '').toString(),
      amount: (data['amount'] is num) ? (data['amount'] as num).toInt() : 0,
      currency: (data['currency'] ?? 'INR').toString(),
      key: (data['key'] ?? data['key_id'] ?? data['razorpay_key'] ?? '').toString(),
    );
  }
}

class InvoiceModel {
  final String rideId;
  final String pickupAddress;
  final String dropAddress;
  final double distance;
  final double duration;
  final double fare;
  final String paymentMode;
  final String paymentStatus;
  final String driverName;

  const InvoiceModel({
    required this.rideId,
    required this.pickupAddress,
    required this.dropAddress,
    required this.distance,
    required this.duration,
    required this.fare,
    required this.paymentMode,
    required this.paymentStatus,
    required this.driverName,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'] is Map<String, dynamic> ? json['driver'] as Map<String, dynamic> : null;
    return InvoiceModel(
      rideId: (json['ride_id'] ?? '').toString(),
      pickupAddress: (json['pickup_address'] ?? '').toString(),
      dropAddress: (json['drop_address'] ?? '').toString(),
      distance: ((json['distance'] ?? 0) as num).toDouble(),
      duration: ((json['duration'] ?? 0) as num).toDouble(),
      fare: ((json['fare'] ?? 0) as num).toDouble(),
      paymentMode: (json['payment_mode'] ?? 'CASH').toString(),
      paymentStatus: (json['payment_status'] ?? 'PENDING').toString(),
      driverName: driver?['name']?.toString() ?? 'N/A',
    );
  }
}
