import 'dart:async';

import 'package:flutter/material.dart';
import 'package:taxiapp/api/driver_api.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/services/active_ride_store.dart';
import 'package:taxiapp/services/driver_socket_service.dart';

/// Shown after drop-off. Ride stays open until payment is confirmed (Razorpay) or cash acknowledged.
class RidePaymentPage extends StatefulWidget {
  final Map<String, dynamic> rideData;

  const RidePaymentPage({super.key, required this.rideData});

  @override
  State<RidePaymentPage> createState() => _RidePaymentPageState();
}

class _RidePaymentPageState extends State<RidePaymentPage> {
  final DriverSocketService _socket = DriverSocketService();
  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _paymentSub;
  String _paymentStatus = 'PENDING';
  String _paymentMode = 'CASH';
  bool _loading = true;
  bool _closing = false;

  String get _rideId =>
      (widget.rideData['ride_id'] ?? widget.rideData['id'] ?? widget.rideData['_id'])
          .toString();

  double get _fare => ((widget.rideData['fare'] as num?) ?? 0).toDouble();

  bool get _isOnline => _paymentMode == 'ONLINE';

  @override
  void initState() {
    super.initState();
    _paymentMode =
        (widget.rideData['payment_mode'] ?? widget.rideData['paymentMode'] ?? 'CASH')
            .toString()
            .toUpperCase();
    _paymentStatus =
        (widget.rideData['payment_status'] ?? widget.rideData['paymentStatus'] ?? 'PENDING')
            .toString()
            .toUpperCase();
    if (_paymentMode == 'CASH') {
      _paymentStatus = 'SUCCESS';
      _loading = false;
    } else {
      _refreshPaymentStatus();
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _refreshPaymentStatus());
    }
    _paymentSub = _socket.paymentSuccessStream.listen(_onPaymentEvent);
    _socket.rideCompletedStream.listen(_onPaymentEvent);
    _socket.rideUpdateStream.listen(_onSocketUpdate);
    if (_rideId.isNotEmpty) _socket.joinRideRoom(_rideId);
  }

  void _onPaymentEvent(Map<String, dynamic> payload) {
    final rideId = (payload['ride_id'] ?? payload['rideId'] ?? '').toString();
    if (rideId.isNotEmpty && rideId != _rideId) return;
    if (!mounted) return;
    setState(() => _paymentStatus = 'SUCCESS');
    if (_isOnline) unawaited(_autoCloseAfterRazorpay(payload));
  }

  Future<void> _autoCloseAfterRazorpay(Map<String, dynamic> payload) async {
    if (_closing) return;
    final earnings = (payload['driver_earnings'] as num?)?.toDouble();
    final msg = earnings != null
        ? 'Razorpay received — ₹${earnings.toStringAsFixed(0)} added to wallet.'
        : 'Razorpay payment received — wallet credited.';
    _showSnack(msg);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await _closeRide();
  }

  void _onSocketUpdate(Map<String, dynamic> payload) {
    final rideId = (payload['ride_id'] ?? payload['rideId'] ?? '').toString();
    if (rideId.isNotEmpty && rideId != _rideId) return;
    final ride = payload['ride'] is Map ? payload['ride'] as Map : payload;
    final status = (ride['payment_status'] ?? ride['paymentStatus'] ?? '').toString();
    if (status.isNotEmpty && mounted) {
      setState(() => _paymentStatus = status.toUpperCase());
      if (_isOnline && (_paymentStatus == 'SUCCESS' || _paymentStatus == 'PAID')) {
        unawaited(_autoCloseAfterRazorpay(payload));
      }
    }
  }

  Future<void> _refreshPaymentStatus() async {
    final token = AuthService().token;
    if (token == null) return;
    final ride = await DriverApi.withToken(token).findRideInHistory(_rideId);
    if (!mounted || ride == null) return;
    setState(() {
      _loading = false;
      _paymentStatus =
          (ride['payment_status'] ?? ride['paymentStatus'] ?? _paymentStatus).toString().toUpperCase();
      _paymentMode =
          (ride['payment_mode'] ?? ride['paymentMode'] ?? _paymentMode).toString().toUpperCase();
    });
    if (_isOnline && (_paymentStatus == 'SUCCESS' || _paymentStatus == 'PAID')) {
      unawaited(_autoCloseAfterRazorpay({}));
    }
  }

  Future<void> _onCashReceived() async {
    final token = AuthService().token;
    if (token == null) return;
    setState(() => _closing = true);
    final ok = await DriverApi.withToken(token).confirmCashReceived(_rideId);
    if (!mounted) return;
    if (ok) {
      setState(() => _paymentStatus = 'SUCCESS');
      _showSnack('Cash recorded.');
    } else {
      setState(() => _closing = false);
      _showSnack('Could not confirm cash.', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  Future<void> _closeRide() async {
    if (_closing) return;
    setState(() => _closing = true);
    final token = AuthService().token;
    if (token != null && !(_isOnline && _paymentComplete)) {
      await DriverApi.withToken(token).completeRide(_rideId);
    }
    await ActiveRideStore.clear();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  bool get _paymentComplete =>
      _paymentStatus == 'SUCCESS' || _paymentStatus == 'PAID' || _paymentMode == 'CASH';

  bool get _paymentFailed => _paymentStatus == 'FAILED';

  Widget _statusChip() {
    Color bg;
    Color fg;
    String label;
    if (_paymentComplete && !_paymentFailed) {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
      label = 'SUCCESS';
    } else if (_paymentFailed) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
      label = 'FAILED';
    } else {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade900;
      label = 'PENDING';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Payment status: $label',
        style: TextStyle(color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _paymentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _paymentComplete,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment'),
          automaticallyImplyLeading: _paymentComplete,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ride completed',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '₹${_fare.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text('Method: ${_isOnline ? 'Razorpay (Online)' : 'Cash'}'),
                      const SizedBox(height: 8),
                      _statusChip(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_isOnline) ...[
                const Text(
                  'Collect cash from the customer, then close the ride.',
                  style: TextStyle(color: Colors.grey),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF072654),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Razorpay',
                        style: TextStyle(
                          color: AppColors.cardDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Customer pays via Razorpay (UPI, cards, wallets) on their app. '
                        'You will be notified when payment succeeds.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
              const Spacer(),
              if (!_isOnline && !_paymentComplete)
                FilledButton(
                  onPressed: _closing ? null : _onCashReceived,
                  child: const Text('CASH RECEIVED'),
                )
              else if (_paymentComplete && !_isOnline)
                FilledButton(
                  onPressed: _closing ? null : _closeRide,
                  child: Text(_closing ? 'Closing...' : 'Payment OK — Back to Dashboard'),
                )
              else if (_paymentComplete && _isOnline && _closing)
                const Center(child: CircularProgressIndicator())
              else if (_paymentFailed && _isOnline)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Customer payment failed. Ask them to retry Razorpay on their app.',
                    style: TextStyle(color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (_isOnline && !_paymentComplete && !_closing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Waiting for Razorpay payment from customer…',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
