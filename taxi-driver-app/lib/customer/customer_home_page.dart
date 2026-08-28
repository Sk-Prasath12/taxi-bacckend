import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taxiapp/api/customer_api.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/fare_calculator.dart';
import 'package:taxiapp/customer/customer_auth_service.dart';
import 'package:taxiapp/customer/payment_page.dart';
import 'package:taxiapp/services/customer_socket_service.dart';
import 'package:taxiapp/services/vehicle_type_service.dart';
import 'package:taxiapp/utils/phone_actions.dart';
import 'package:taxiapp/widgets/taxi_ui.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final _socket = CustomerSocketService();
  final _pickupAddressCtrl = TextEditingController(text: 'BSR Mall, Chennai');
  final _pickupLatCtrl = TextEditingController(text: '12.97598');
  final _pickupLngCtrl = TextEditingController(text: '80.22120');
  final _dropAddressCtrl = TextEditingController(text: 'VIT Chennai');
  final _dropLatCtrl = TextEditingController(text: '12.9268');
  final _dropLngCtrl = TextEditingController(text: '80.1203');

  StreamSubscription<Map<String, dynamic>>? _acceptedSub;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  StreamSubscription<Map<String, dynamic>>? _paymentSub;
  StreamSubscription<Map<String, dynamic>>? _paymentSuccessSub;
  StreamSubscription<Map<String, dynamic>>? _rideCompletedSub;
  Timer? _statusPollTimer;

  bool _loading = false;
  String _status = 'Ready to book';
  String? _rideId;
  String? _otp;
  String? _dropOtp;
  bool _otpVerified = false;
  bool _dropOtpVerified = false;
  String? _driverName;
  String? _driverPhone;
  double? _fare;
  bool _needsConfirm = false;
  bool _rideCompleted = false;
  String _paymentMode = 'CASH';
  String? _paymentOrderId;
  String? _qrPayload;
  List<Map<String, dynamic>> _vehicles = [];
  String? _vehicleId;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    unawaited(_resumeActiveRide());
  }

  @override
  void dispose() {
    _acceptedSub?.cancel();
    _statusSub?.cancel();
    _paymentSub?.cancel();
    _paymentSuccessSub?.cancel();
    _rideCompletedSub?.cancel();
    _statusPollTimer?.cancel();
    _pickupAddressCtrl.dispose();
    _pickupLatCtrl.dispose();
    _pickupLngCtrl.dispose();
    _dropAddressCtrl.dispose();
    _dropLatCtrl.dispose();
    _dropLngCtrl.dispose();
    super.dispose();
  }

  double? _estimateDistanceKm() {
    final plat = double.tryParse(_pickupLatCtrl.text);
    final plng = double.tryParse(_pickupLngCtrl.text);
    final dlat = double.tryParse(_dropLatCtrl.text);
    final dlng = double.tryParse(_dropLngCtrl.text);
    if (plat == null || plng == null || dlat == null || dlng == null) return null;
    const r = 6371.0;
    final dLat = _deg2rad(dlat - plat);
    final dLng = _deg2rad(dlng - plng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(plat)) * math.cos(_deg2rad(dlat)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  double _deg2rad(double deg) => deg * math.pi / 180;

  Future<void> _loadVehicles() async {
    final auth = CustomerAuthService();
    if (!auth.isLoggedIn) return;
    try {
      final list = await VehicleTypeService.fetchActive(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _vehicles = list
            .map((v) => <String, dynamic>{
                  'id': v.id,
                  'name': v.displayLabel,
                  'code': v.code,
                  'perKmRate': v.perKmRate,
                  'maxPassengers': v.maxPassengers,
                })
            .toList();
        _vehicleId = list.isNotEmpty ? list.first.id : null;
      });
    } catch (_) {
      final list = await CustomerApi.withToken(auth.token).getVehicleTypes();
      if (!mounted) return;
      setState(() {
        _vehicles = list;
        _vehicleId = list.isNotEmpty ? list.first['id']?.toString() : null;
      });
    }
  }

  Future<void> _resumeActiveRide() async {
    final auth = CustomerAuthService();
    if (!auth.isLoggedIn) return;
    final ride = await CustomerApi.withToken(auth.token).getActiveRide();
    if (!mounted || ride == null) return;
    final id = (ride['ride_id'] ?? ride['id'] ?? '').toString();
    if (id.isEmpty) return;
    setState(() {
      _rideId = id;
      _applyRideStateFromMap(ride, ride['status']?.toString() ?? '');
    });
    if (!_needsConfirm) {
      _connectSocket(id);
      _startStatusPoll();
    }
  }

  Future<void> _useGpsAsPickup() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _snack('Location permission is required to fill pickup.', error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _pickupLatCtrl.text = pos.latitude.toStringAsFixed(6);
        _pickupLngCtrl.text = pos.longitude.toStringAsFixed(6);
        if (_pickupAddressCtrl.text.trim().isEmpty || _pickupAddressCtrl.text.contains('BSR Mall')) {
          _pickupAddressCtrl.text = 'Current location';
        }
      });
    } catch (e) {
      _snack('Could not read GPS: $e', error: true);
    }
  }

  Future<void> _cancelRide() async {
    if (_rideId == null) return;
    setState(() => _loading = true);
    final ok = await CustomerApi.withToken(CustomerAuthService().token).cancelRide(_rideId!);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      _snack('Cancel failed', error: true);
      return;
    }
    _stopStatusPoll();
    _socket.disconnect();
    _finishLocalRide();
    _snack('Ride cancelled');
  }

  Future<void> _showHistory() async {
    final list = await CustomerApi.withToken(CustomerAuthService().token).getRideHistory();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: list.isEmpty
              ? const Center(child: Text('No ride history yet'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, i) {
                    final r = list[i];
                    final pickup = r['pickup'] is Map ? r['pickup']['address'] : r['pickup'];
                    final drop = r['drop'] is Map ? r['drop']['address'] : r['drop'];
                    final driverPhone = r['driver_phone']?.toString() ??
                        (r['driver'] is Map ? (r['driver'] as Map)['phone']?.toString() : null);
                    return ListTile(
                      title: Text('${r['status'] ?? ''} · ₹${r['fare'] ?? '—'}'),
                      subtitle: Text('${pickup ?? 'Pickup'} → ${drop ?? 'Drop'}'),
                      trailing: (driverPhone != null && driverPhone.isNotEmpty)
                          ? IconButton(
                              icon: const Icon(Icons.phone),
                              onPressed: () => showPhoneActions(ctx, driverPhone, roleLabel: 'Driver'),
                            )
                          : null,
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _connectSocket(String rideId) {
    final auth = CustomerAuthService();
    _acceptedSub?.cancel();
    _statusSub?.cancel();
    _paymentSub?.cancel();
    _paymentSuccessSub?.cancel();
    _rideCompletedSub?.cancel();
    unawaited(_socket.connect(token: auth.token!, customerId: auth.userId!, rideId: rideId));
    _acceptedSub = _socket.rideAcceptedStream.listen(_onAccepted);
    _statusSub = _socket.statusUpdateStream.listen(_onStatus);
    _paymentSub = _socket.paymentPendingStream.listen(_onPaymentPending);
    _paymentSuccessSub = _socket.paymentSuccessStream.listen(_onPaymentSuccess);
    _rideCompletedSub = _socket.rideCompletedStream.listen(_onRideCompleted);
  }

  String get _normalizedPaymentMode =>
      _paymentMode == 'UPI' ? 'ONLINE' : _paymentMode;

  String get _paymentModeLabel {
    switch (_normalizedPaymentMode) {
      case 'ONLINE':
        return 'Razorpay (Online)';
      default:
        return 'Cash';
    }
  }

  void _startStatusPoll() {
    _statusPollTimer?.cancel();
    unawaited(_refreshStatus());
    _statusPollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refreshStatus());
  }

  void _stopStatusPoll() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
  }

  String? _readOtp(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return s;
  }

  Future<void> _refreshStatus() async {
    if (_rideId == null) return;
    final auth = CustomerAuthService();
    final ride = await CustomerApi.withToken(auth.token).getRideStatus(_rideId!);
    if (!mounted || ride == null) return;
    final status = ride['client_status']?.toString() ?? ride['status']?.toString() ?? '';
    setState(() {
      _applyRideStateFromMap(ride, status);
    });
    final raw = (ride['status'] ?? '').toString().toUpperCase();
    if (raw == 'COMPLETED') _stopStatusPoll();
  }

  void _applyRideStateFromMap(Map<String, dynamic> ride, String status) {
    final pickupOtp = _readOtp(ride['otp']);
    if (pickupOtp != null) _otp = pickupOtp;
    final dropOtp = _readOtp(ride['drop_otp']);
    if (dropOtp != null) _dropOtp = dropOtp;
    _otpVerified = ride['otp_verified'] == true || _otpVerified;
    _dropOtpVerified = ride['drop_otp_verified'] == true || _dropOtpVerified;
    final rideFare = (ride['fare'] as num?)?.toDouble();
    if (rideFare != null && rideFare > 0) _fare = rideFare;
    final upper = status.toUpperCase();
    _needsConfirm = upper == 'PENDING_CONFIRMATION';
    if (status.toLowerCase() == 'requested') {
      _needsConfirm = ride['dispatchedAt'] == null;
    }
    _rideCompleted = upper == 'COMPLETED' ||
        upper == 'COMPLETED_PENDING_PAYMENT' ||
        upper == 'DROP_OTP_VERIFIED';
    _status = _label(status);
    _driverName = ride['driver_name']?.toString() ?? _driverNameFromRide(ride) ?? _driverName;
    _driverPhone = ride['driver_phone']?.toString() ??
        (ride['driver'] is Map ? (ride['driver'] as Map)['phone']?.toString() : null) ??
        _driverPhone;
  }

  void _onPaymentPending(Map<String, dynamic> p) {
    if (!mounted) return;
    final event = (p['event'] ?? p['type'] ?? p['status'] ?? '').toString().toUpperCase();
    final isPayment = event.contains('PAYMENT') || p['payment_status'] != null || p['fare'] != null;
    if (!isPayment) return;
    setState(() {
      final fare = (p['fare'] as num?)?.toDouble();
      if (fare != null && fare > 0) _fare = fare;
      if (p['drop_otp'] != null) _dropOtp = p['drop_otp'].toString();
      if (p['ride'] is Map) {
        final ride = p['ride'] as Map;
        final nestedFare = (ride['fare'] as num?)?.toDouble();
        if (nestedFare != null && nestedFare > 0) _fare = nestedFare;
      }
      _rideCompleted = true;
      _status = 'Payment required — pay ₹${_fare?.toStringAsFixed(0) ?? '—'} (${_paymentModeLabel})';
    });
    if (_normalizedPaymentMode == 'ONLINE' && !_loading) {
      unawaited(_payOnline());
    }
  }

  void _onPaymentSuccess(Map<String, dynamic> p) {
    if (!mounted) return;
    setState(() {
      _status = 'Payment successful — ride closed';
      _rideCompleted = true;
    });
    _snack('Payment successful. Ride completed.');
    _finishLocalRide();
  }

  void _onRideCompleted(Map<String, dynamic> p) {
    if (!mounted) return;
    setState(() => _status = 'Ride completed');
    _finishLocalRide();
  }

  void _onAccepted(Map<String, dynamic> p) {
    if (!mounted) return;
    setState(() {
      _status = 'Driver assigned — on the way';
      _needsConfirm = false;
      _driverName = p['driver_name']?.toString() ??
          (p['driver'] is Map ? p['driver']['name']?.toString() : null) ??
          'Your driver';
      _driverPhone = p['driver_phone']?.toString() ??
          (p['driver'] is Map ? p['driver']['phone']?.toString() : null) ??
          _driverPhone;
    });
  }

  void _applyPickupOtpFromPayload(Map<String, dynamic> p) {
    final direct = _readOtp(p['otp']);
    if (direct != null) {
      _otp = direct;
      return;
    }
    if (p['ride'] is Map) {
      final ride = p['ride'] as Map;
      final nested = _readOtp(ride['otp']);
      if (nested != null) _otp = nested;
    }
  }

  void _onStatus(Map<String, dynamic> p) {
    if (!mounted) return;
    final s = (p['client_status'] ?? p['status'] ?? p['ride']?['status'] ?? '').toString();
    final lat = (p['lat'] ?? p['latitude'] ?? p['driver_lat']) as num?;
    final lng = (p['lng'] ?? p['longitude'] ?? p['driver_lng']) as num?;
    if (s.isEmpty &&
        p['fare'] == null &&
        p['otp'] == null &&
        p['drop_otp'] == null &&
        p['otp_verified'] == null &&
        lat == null &&
        lng == null) {
      return;
    }
    setState(() {
      if (s.isNotEmpty) _status = _label(s);
      _applyPickupOtpFromPayload(p);
      final dropDirect = _readOtp(p['drop_otp']);
      if (dropDirect != null) _dropOtp = dropDirect;
      if (p['otp_verified'] == true) _otpVerified = true;
      if (p['drop_otp_verified'] == true) _dropOtpVerified = true;
      final topFare = (p['fare'] as num?)?.toDouble();
      if (topFare != null && topFare > 0) _fare = topFare;
      if (p['ride'] is Map) {
        final ride = p['ride'] as Map;
        final nestedOtp = _readOtp(ride['otp']);
        if (nestedOtp != null) _otp = nestedOtp;
        final nestedDrop = _readOtp(ride['drop_otp']);
        if (nestedDrop != null) _dropOtp = nestedDrop;
        if (ride['otp_verified'] == true) _otpVerified = true;
        if (ride['drop_otp_verified'] == true) _dropOtpVerified = true;
        final nestedFare = (ride['fare'] as num?)?.toDouble();
        if (nestedFare != null && nestedFare > 0) _fare = nestedFare;
      }
      final upper = s.toUpperCase();
      if (upper == 'COMPLETED' ||
          upper == 'COMPLETED_PENDING_PAYMENT' ||
          upper == 'DROP_OTP_VERIFIED') {
        _rideCompleted = true;
      }
      if (upper == 'COMPLETED') _stopStatusPoll();
    });
  }

  String? _driverNameFromRide(Map<String, dynamic> ride) {
    final driver = ride['driver'];
    if (driver is Map) return driver['name']?.toString();
    return null;
  }

  String _label(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING_CONFIRMATION':
        return 'Fare ready — tap Confirm to send to drivers';
      case 'SEARCHING_DRIVER':
      case 'SEARCHING':
      case 'REQUESTED':
        return 'Searching for nearby drivers…';
      case 'DRIVER_ASSIGNED':
      case 'ACCEPTED':
        return 'Driver assigned';
      case 'ARRIVED_AT_PICKUP':
      case 'ARRIVED':
        return 'Driver arrived — show pickup OTP';
      case 'STARTED':
        return 'Ride started';
      case 'PICKED_UP':
        return 'Passenger picked up';
      case 'IN_TRANSIT':
        return 'On the way to drop';
      case 'DROP_REACHED':
        return 'Drop reached — show drop OTP';
      case 'DROP_OTP_VERIFIED':
        return 'Drop OTP verified — payment';
      case 'COMPLETED_PENDING_PAYMENT':
        return 'Payment required';
      case 'COMPLETED':
        return 'Ride completed';
      default:
        return s;
    }
  }

  Future<void> _requestRide() async {
    final auth = CustomerAuthService();
    final pickupLat = double.tryParse(_pickupLatCtrl.text.trim());
    final pickupLng = double.tryParse(_pickupLngCtrl.text.trim());
    final dropLat = double.tryParse(_dropLatCtrl.text.trim());
    final dropLng = double.tryParse(_dropLngCtrl.text.trim());
    final pickupAddr = _pickupAddressCtrl.text.trim();
    final dropAddr = _dropAddressCtrl.text.trim();

    if (pickupLat == null ||
        pickupLng == null ||
        dropLat == null ||
        dropLng == null ||
        pickupAddr.isEmpty ||
        dropAddr.isEmpty) {
      _snack('Please enter valid pickup/drop location and coordinates.', error: true);
      return;
    }
    if (_vehicleId == null || _vehicleId!.isEmpty) {
      _snack('Please select a vehicle type.', error: true);
      return;
    }

    setState(() => _loading = true);
    final api = CustomerApi.withToken(auth.token);
    await api.abandonStaleActiveRide();
    final res = await api.requestRide(
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      pickupAddress: pickupAddr,
      dropLat: dropLat,
      dropLng: dropLng,
      dropAddress: dropAddr,
      vehicleTypeId: _vehicleId!,
      paymentMode: _normalizedPaymentMode,
      paymentMethod: _paymentMode,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _rideCompleted = false;
      _paymentOrderId = null;
      _qrPayload = null;
      _driverName = null;
      _driverPhone = null;
    });
    if (res == null || res['ride_id'] == null) {
      _snack('Request failed. Check zone or server.', error: true);
      return;
    }
    setState(() {
      _rideId = res['ride_id'].toString();
      _fare = (res['fare'] as num?)?.toDouble();
      _needsConfirm = true;
      _status = _label('PENDING_CONFIRMATION');
    });
    _snack('Ride created. Ride ID: $_rideId — tap Confirm to notify drivers.');
  }

  Future<void> _confirmRide() async {
    if (_rideId == null) return;
    final auth = CustomerAuthService();
    setState(() => _loading = true);
    final conf = await CustomerApi.withToken(auth.token).confirmRide(
      _rideId!,
      paymentMode: _normalizedPaymentMode,
      paymentMethod: _paymentMode,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (conf == null) {
      _snack('Confirm failed', error: true);
      return;
    }
    final ride = conf['ride'] is Map ? conf['ride'] as Map : {};
    setState(() {
      _otp = conf['otp']?.toString() ?? ride['otp']?.toString() ?? _otp;
      _otpVerified = false;
      _dropOtp = null;
      _dropOtpVerified = false;
      _fare = (ride['fare'] as num?)?.toDouble() ?? _fare;
      _needsConfirm = false;
      _status = _label('SEARCHING_DRIVER');
    });
    if (conf['ride_id'] != null) {
      _rideId = conf['ride_id'].toString();
    }
    _connectSocket(_rideId!);
    _startStatusPoll();
    unawaited(_refreshStatus());
    final nearbyCount = (conf['nearby_drivers_count'] as num?)?.toInt();
    final msg = conf['message']?.toString() ?? '';
    if (msg.toLowerCase().contains('no nearby') || nearbyCount == 0) {
      _snack('No nearby drivers available within ${conf['nearby_radius_km'] ?? 10} km. Keep waiting or retry.', error: true);
    } else {
      _snack('Searching nearby drivers (${nearbyCount ?? "…"} within ${conf['nearby_radius_km'] ?? 10} km)');
    }
  }

  Future<void> _payOnline() async {
    if (_rideId == null) return;
    setState(() => _loading = true);
    final auth = CustomerAuthService();
    final ride = await CustomerApi.withToken(auth.token).getRideStatus(_rideId!);
    if (ride != null) {
      final fare = (ride['fare'] as num?)?.toDouble();
      if (fare != null && fare > 0) _fare = fare;
    }
    final order = await CustomerApi.withToken(auth.token).createPaymentOrder(_rideId!);
    if (!mounted) return;
    setState(() => _loading = false);
    if (order == null || order['success'] != true || order['order_id'] == null) {
      final msg = order?['message']?.toString() ?? 'Payment order failed. Use CASH or check Razorpay config.';
      _snack(msg, error: true);
      return;
    }
    final amountRupees = ((order['amount'] as num?) ?? 0) / 100;
    if (amountRupees <= 0) {
      _snack('Invalid fare (₹0). Ask driver to confirm drop again.', error: true);
      return;
    }
    _fare = amountRupees;
    setState(() => _paymentOrderId = order['order_id'].toString());
    _snack('Razorpay order: ${order['order_id']} (₹${amountRupees.toStringAsFixed(0)})');
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerPaymentPage(rideId: _rideId!, amount: amountRupees),
      ),
    );
    if (paid == true) {
      _finishLocalRide();
      _snack('Razorpay paid — ride closed.');
      return;
    }
  }

  String _buildUpiPayload() {
    final amount = (_fare ?? 0).toStringAsFixed(2);
    return 'upi://pay?pa=exampletaxi@upi&pn=Taxi Driver Demo&am=$amount&cu=INR&tn=Ride%20$_rideId';
  }

  void _showUpiQr() {
    final payload = _buildUpiPayload();
    final encoded = Uri.encodeComponent(payload);
    final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=260x260&data=$encoded';

    setState(() => _qrPayload = payload);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('UPI / Online Payment QR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Image.network(qrUrl, width: 220, height: 220)),
            const SizedBox(height: 10),
            const Text('Example bank account'),
            const SizedBox(height: 4),
            const Text('A/C: 1234567890'),
            const Text('IFSC: EXAM0001234'),
            const Text('UPI: exampletaxi@upi'),
            const SizedBox(height: 10),
            Text(
              payload,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _finishLocalRide() {
    _stopStatusPoll();
    _socket.disconnect();
    setState(() {
      _rideId = null;
      _otp = null;
      _dropOtp = null;
      _otpVerified = false;
      _dropOtpVerified = false;
      _driverName = null;
      _driverPhone = null;
      _fare = null;
      _needsConfirm = false;
      _rideCompleted = false;
      _paymentOrderId = null;
      _qrPayload = null;
      _status = 'Ready to book';
    });
    _snack('Ride closed successfully.');
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  bool get _showPickupOtp =>
      !_needsConfirm && !_otpVerified && _otp != null && _otp!.isNotEmpty;

  bool get _showDropOtp => !_dropOtpVerified && _dropOtp != null && _dropOtp!.isNotEmpty;

  Widget _otpShareCard({required String title, required String code, required String hint}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            code,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = CustomerAuthService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer — Book Ride'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Ride history',
            onPressed: _showHistory,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              _stopStatusPoll();
              _socket.disconnect();
              await auth.logout();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live ride status', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(_status, style: Theme.of(context).textTheme.titleLarge),
                  if (_driverName != null)
                    Text('Driver: $_driverName', style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (_driverPhone != null && _driverPhone!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => showPhoneActions(context, _driverPhone!, roleLabel: 'Driver'),
                            icon: const Icon(Icons.phone),
                            label: const Text('Call Driver'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_rideId != null)
                    Text('Ride ID: $_rideId', style: Theme.of(context).textTheme.bodySmall),
                  if (_showPickupOtp) ...[
                    const SizedBox(height: 12),
                    _otpShareCard(
                      title: 'Pickup OTP',
                      code: _otp!,
                      hint: 'Show this 4-digit code to the driver at pickup.',
                    ),
                  ] else if (_otpVerified) ...[
                    const SizedBox(height: 8),
                    const Text('Pickup OTP verified — trip started',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                  if (_showDropOtp) ...[
                    const SizedBox(height: 12),
                    _otpShareCard(
                      title: 'Drop OTP',
                      code: _dropOtp!,
                      hint: 'Show this code to the driver at drop. Different from pickup OTP.',
                    ),
                  ] else if (_dropOtpVerified) ...[
                    const SizedBox(height: 8),
                    const Text('Drop OTP verified — complete payment',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                  if (_rideId != null)
                    Text('Payment method: $_paymentModeLabel', style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (_fare != null) ...[
                    Text(
                      'Estimated fare: ₹${_fare!.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    if (_estimateDistanceKm() != null)
                      TaxiFareBreakdown(
                        distanceKm: _estimateDistanceKm()!,
                        durationMin: _estimateDistanceKm()! * 2,
                        compact: true,
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Cancel fee: ₹${FareCalculator.cancellationFee.toStringAsFixed(0)} (driver receives this)',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 8),
          Text(
            'Drivers are matched to the Pickup lat/lng below (selected pickup), not your phone GPS.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _rideId == null ? _useGpsAsPickup : null,
            icon: const Icon(Icons.my_location),
            label: const Text('Use GPS as selected pickup'),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.trip_origin, color: Colors.green),
            title: TextField(
              controller: _pickupAddressCtrl,
              decoration: const InputDecoration(
                labelText: 'Selected pickup address',
                border: OutlineInputBorder(),
              ),
            ),
            subtitle: const Text('Selected pickup (used for driver matching)'),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pickupLatCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Selected pickup lat'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _pickupLngCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Selected pickup lng'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.place, color: Colors.red),
            title: TextField(
              controller: _dropAddressCtrl,
              decoration: const InputDecoration(
                labelText: 'Drop address',
                border: OutlineInputBorder(),
              ),
            ),
            subtitle: const Text('Drop-off'),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dropLatCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Drop lat'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _dropLngCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Drop lng'),
                ),
              ),
            ],
          ),
          if (_vehicles.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _vehicleId,
              decoration: const InputDecoration(labelText: 'Vehicle', border: OutlineInputBorder()),
              items: _vehicles
                  .map((v) {
                    final seats = v['maxPassengers'];
                    final rate = v['perKmRate'];
                    final name = v['name']?.toString() ?? '';
                    final detail = (seats != null && rate != null)
                        ? '$name · $seats seats · ₹$rate/km'
                        : name;
                    return DropdownMenuItem(
                      value: v['id']?.toString(),
                      child: Text(detail, overflow: TextOverflow.ellipsis),
                    );
                  })
                  .toList(),
              onChanged: _rideId == null ? (v) => setState(() => _vehicleId = v) : null,
            ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _paymentMode,
            decoration: const InputDecoration(labelText: 'Payment method', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'CASH', child: Text('Cash')),
              DropdownMenuItem(value: 'UPI', child: Text('UPI / QR')),
              DropdownMenuItem(value: 'ONLINE', child: Text('Online (Gateway)')),
            ],
            onChanged: _rideId == null
                ? (v) {
                    if (v != null) setState(() => _paymentMode = v);
                  }
                : null,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading || _rideId != null && !_needsConfirm && !_rideCompleted
                ? null
                : _requestRide,
            icon: const Icon(Icons.add_road),
            label: const Text('1. Request Ride'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _loading || !_needsConfirm ? null : _confirmRide,
            icon: const Icon(Icons.check_circle),
            label: const Text('2. Confirm & notify drivers'),
          ),
          if (_rideId != null && !_rideCompleted) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loading ? null : _cancelRide,
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel ride'),
            ),
          ],
          if (_rideCompleted) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment', style: Theme.of(context).textTheme.titleMedium),
                    if (_fare != null && _fare! > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Amount due: ₹${_fare!.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (_paymentMode == 'CASH')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pay your driver in cash and finish ride.'),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _finishLocalRide,
                            child: const Text('Finish Ride (Cash Paid)'),
                          ),
                        ],
                      )
                    else ...[
                      const Text('Complete UPI/online payment for this ride.'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: _loading ? null : _showUpiQr,
                            child: const Text('Generate QR Code'),
                          ),
                          FilledButton.tonal(
                            onPressed: _loading ? null : _payOnline,
                            child: const Text('Create Online Order'),
                          ),
                        ],
                      ),
                      if (_qrPayload != null)
                        Text('QR ready: $_qrPayload', style: Theme.of(context).textTheme.bodySmall),
                      if (_paymentOrderId != null)
                        Text('Order: $_paymentOrderId', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _finishLocalRide,
                        child: const Text('Payment Done - Close Ride'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Flow: Request with your location → Confirm → driver sees route and accepts → OTP at pickup → '
            'drop location tracking → payment (Cash/UPI/Online) → close ride.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
