import 'package:flutter/material.dart';
import 'package:taxiapp/api/driver_api.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/fare_calculator.dart';
import '../ride_flow_navigator.dart';
import '../ride_flow_routes.dart';
import '../ride_flow_service.dart';
import '../widgets/ride_flow_scaffold.dart';
import '../widgets/ride_map_widget.dart';

/// Page 6 — Drop reached + drop OTP verification on one screen.
class RideDropReachedPage extends StatefulWidget {
  const RideDropReachedPage({super.key});

  @override
  State<RideDropReachedPage> createState() => _RideDropReachedPageState();
}

class _RideDropReachedPageState extends State<RideDropReachedPage> {
  final _otpController = TextEditingController();
  final _flow = RideFlowService.instance;
  bool _loading = false;
  bool _verifyingOtp = false;
  late bool _submitted;

  @override
  void initState() {
    super.initState();
    _submitted = _flow.ride['drop_reached'] == true || _flow.ride['drop_otp'] != null;
    _flow.rideNotifier.addListener(_onRideUpdate);
  }

  void _onRideUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _flow.rideNotifier.removeListener(_onRideUpdate);
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submitDrop() async {
    final token = await _flow.requireToken();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.'), backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() => _loading = true);
    final loc = _flow.currentLocation;
    final billableKm = _flow.billableTripKm;
    final fare = _flow.tripTracker.estimateKmOnlyFare(distanceKm: billableKm).roundToDouble();
    final result = await DriverApi.withToken(token).markDroppedResult(
      _flow.rideId,
      fare: fare,
      lat: loc?.latitude,
      lng: loc?.longitude,
      actualDistanceKm: billableKm,
      durationMin: _flow.tripTracker.durationMin,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _submitted = result.success;
    });
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Drop update failed'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    _flow.tripTracker.stop();
    final data = result.data is Map ? Map<String, dynamic>.from(result.data as Map) : <String, dynamic>{};
    _flow.mergeRide({
      ..._flow.ride,
      'drop_reached': true,
      'fare': data['fare'] ?? fare,
      'actual_distance_km': billableKm,
      if (data['drop_otp'] != null) 'drop_otp': data['drop_otp'],
    });
    await _flow.mergeFromServer();
    await _flow.save();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _verifyDropOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter drop OTP'), backgroundColor: AppColors.danger),
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
    setState(() => _verifyingOtp = true);
    final result = await DriverApi.withToken(token).verifyDropOtpResult(_flow.rideId, otp);
    if (!mounted) return;
    setState(() => _verifyingOtp = false);
    if (!result.success) {
      final msg = result.message ?? 'Invalid drop OTP';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.toLowerCase().contains('invalid')
                ? '$msg — use the new Drop OTP from the customer app.'
                : msg,
          ),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }
    _flow.mergeRide({
      ..._flow.ride,
      'drop_otp_verified': true,
      'status': 'COMPLETED_PENDING_PAYMENT',
      'payment_status': 'PENDING',
    });
    await RideFlowNavigator.go(context, RideFlowRoutes.payment);
  }

  @override
  Widget build(BuildContext context) {
    final loc = _flow.currentLocation;
    final billableKm = _flow.billableTripKm;
    final busy = _loading || _verifyingOtp;

    return RideFlowScaffold(
      title: 'Drop Reached',
      canPop: true,
      bottomButton: rideFlowButton(
        label: _submitted ? 'CONFIRM VERIFY DROP OTP' : 'CONFIRM DROP LOCATION',
        onPressed: busy ? null : (_submitted ? _verifyDropOtp : _submitDrop),
      ),
      children: [
        RideMapWidget(
          driver: _flow.currentLocation ?? _flow.drop,
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
                const Text('Actual GPS drop', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  loc != null
                      ? '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}'
                      : 'Waiting for GPS…',
                ),
                const SizedBox(height: 12),
                Text('Distance travelled: ${billableKm.toStringAsFixed(2)} km'),
                Text(
                  'Fare (km only): ₹${_flow.tripTracker.estimateKmOnlyFare(distanceKm: billableKm).round()}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹${FareCalculator.perKm.toStringAsFixed(0)}/km · actual GPS distance',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (_submitted) ...[
          const SizedBox(height: 16),
          Card(
            color: AppColors.greenLight,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'A new Drop OTP was sent to the customer app. '
                'It is different from the pickup OTP.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Enter drop OTP from customer app'),
          const SizedBox(height: 8),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(
              labelText: 'Drop OTP',
              hintText: 'Enter OTP from customer',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
        ],
      ],
    );
  }
}
