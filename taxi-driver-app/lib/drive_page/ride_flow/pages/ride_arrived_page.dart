import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taxiapp/api/driver_api.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/taxi_icons.dart';

import '../ride_flow_navigator.dart';
import '../ride_flow_routes.dart';
import '../ride_flow_service.dart';
import '../widgets/ride_flow_scaffold.dart';
import '../widgets/ride_map_widget.dart';
import '../widgets/driver_cancel_ride.dart';

/// Page 2 — Arrived at pickup + pickup OTP on one screen.
class RideArrivedPage extends StatefulWidget {
  const RideArrivedPage({super.key});

  @override
  State<RideArrivedPage> createState() => _RideArrivedPageState();
}

class _RideArrivedPageState extends State<RideArrivedPage> {
  final _otpController = TextEditingController();
  final _flow = RideFlowService.instance;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _flow.rideNotifier.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureArrivedOnce());
  }

  /// Marks arrived if driver opened this screen without swiping ARRIVED (e.g. web refresh).
  Future<void> _ensureArrivedOnce() async {
    final status = _flow.status.toUpperCase();
    if (status == 'ARRIVED_AT_PICKUP' || status == 'ARRIVED' || status == 'STARTED') return;
    final token = await _flow.requireToken();
    if (token == null) return;
    final result = await DriverApi.withToken(token).markArrivedResult(_flow.rideId);
    if (result.success || (result.message ?? '').toLowerCase().contains('already')) {
      _flow.mergeRide({..._flow.ride, 'status': 'ARRIVED_AT_PICKUP'});
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _flow.rideNotifier.removeListener(_rebuild);
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyPickupOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter pickup OTP'), backgroundColor: AppColors.danger),
      );
      return;
    }
    final token = await _flow.requireToken();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.'), backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() => _loading = true);
    final api = DriverApi.withToken(token);
    final verifyResult = await api.verifyRideOtpResult(_flow.rideId, otp);
    if (!mounted) return;
    final verifyOk = verifyResult.success ||
        (verifyResult.message ?? '').toLowerCase().contains('already verified');
    if (!verifyOk) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(verifyResult.message ?? 'Invalid pickup OTP'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    final body = verifyResult.data is Map
        ? Map<String, dynamic>.from(verifyResult.data as Map)
        : <String, dynamic>{};
    if (body['ride'] is Map) {
      _flow.mergeRide(Map<String, dynamic>.from(body['ride'] as Map));
    }
    _flow.mergeRide({
      ..._flow.ride,
      'otp_verified': true,
      'trip_started': true,
      'status': (body['status'] ?? 'STARTED').toString(),
    });
    _flow.tripTracker.start(from: _flow.currentLocation);
    // Ignore: fire-and-forget route load so OTP verify screen does not wait.
    // ignore: unawaited_futures
    _flow.loadRoute(toPickup: false);
    if (!mounted) return;
    setState(() => _loading = false);
    await RideFlowNavigator.go(context, RideFlowRoutes.ongoing);
  }

  @override
  Widget build(BuildContext context) {
    final ride = _flow.ride;
    final phone = _flow.customerPhone();

    return RideFlowScaffold(
      title: 'Arrived at Pickup',
      canPop: true,
      bottomButton: rideFlowButton(
        label: 'CONFIRM OTP & GO TO DROP',
        icon: TaxiIcons.otp,
        onPressed: _loading ? null : _verifyPickupOtp,
      ),
      children: [
        RideMapWidget(
          driver: _flow.currentLocation ?? _flow.pickup,
          pickup: _flow.pickup,
          drop: _flow.drop,
          route: _flow.routePolyline,
          heading: _flow.heading,
          customerLabel: _flow.customerName(),
          onRefreshLocation: _flow.refreshDriverLocation,
          height: 220,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_flow.customerName(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Mobile: ${phone.isEmpty ? '—' : phone}'),
                const SizedBox(height: 12),
                const Text('Pickup location', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(_flow.locationLabel(ride['pickup'], fallback: 'Pickup')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Enter the pickup OTP shown on the customer app.'),
        const SizedBox(height: 4),
        const Text(
          'Use the 4-digit pickup OTP shown on the customer app. It stays the same after ARRIVED.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: const InputDecoration(
            labelText: 'Pickup OTP',
            hintText: '4-digit code',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        if (ride['otp_verified'] != true) ...[
          OutlinedButton.icon(
            onPressed: _loading ? null : () => showDriverCancelRideDialog(context),
            icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
            label: const Text('Cancel Ride', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ],
    );
  }
}
