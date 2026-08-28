import 'dart:async';

import 'package:flutter/material.dart';
import 'package:taxiapp/api/driver_api.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/taxi_icons.dart';
import 'package:taxiapp/services/active_ride_store.dart';

import '../ride_flow_navigator.dart';
import '../ride_flow_routes.dart';
import '../ride_flow_service.dart';
import '../widgets/ride_flow_scaffold.dart';

/// Razorpay: auto wallet + auto close. Cash: manual CASH RECEIVED.
class RideFlowPaymentPage extends StatefulWidget {
  const RideFlowPaymentPage({super.key});

  @override
  State<RideFlowPaymentPage> createState() => _RideFlowPaymentPageState();
}

class _RideFlowPaymentPageState extends State<RideFlowPaymentPage> {
  final _flow = RideFlowService.instance;
  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _successSub;
  StreamSubscription<Map<String, dynamic>>? _failedSub;
  StreamSubscription<Map<String, dynamic>>? _completedSub;
  String _paymentStatus = 'PENDING';
  String _paymentMode = 'CASH';
  bool _loading = false;
  bool _closing = false;
  bool _paymentHandled = false;
  double? _walletBalance;
  double? _driverEarnings;

  @override
  void initState() {
    super.initState();
    _paymentMode =
        (_flow.ride['payment_mode'] ?? _flow.ride['paymentMode'] ?? 'CASH').toString().toUpperCase();
    _paymentStatus =
        (_flow.ride['payment_status'] ?? _flow.ride['paymentStatus'] ?? 'PENDING').toString().toUpperCase();
    if (_flow.rideId.isNotEmpty) {
      unawaited(_flow.connectSocket());
      _flow.socket.joinRideRoom(_flow.rideId);
    }
    _successSub = _flow.socket.paymentSuccessStream.listen(_onPaymentEvent);
    _completedSub = _flow.socket.rideCompletedStream.listen(_onPaymentEvent);
    _failedSub = _flow.socket.paymentFailedStream.listen(_onPaymentFailed);
    _flow.rideNotifier.addListener(_onRideStateChanged);
    if (_isOnline) {
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
      unawaited(_refresh());
      if (_isPaidPayload(_flow.ride)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_paymentHandled) _onPaymentEvent(_flow.ride);
        });
      }
    }
  }

  bool get _isOnline => _paymentMode == 'ONLINE';

  bool get _paid => _paymentStatus == 'SUCCESS' || _paymentStatus == 'PAID';

  bool get _rideClosed => _flow.status == 'COMPLETED';

  bool _isPaidPayload(Map<String, dynamic> payload) {
    final ps = (payload['payment_status'] ?? payload['paymentStatus'] ?? '').toString().toUpperCase();
    final st = (payload['status'] ?? '').toString().toUpperCase();
    if (ps == 'SUCCESS' || ps == 'PAID' || st == 'COMPLETED') return true;
    if (_isOnline &&
        _matchesRide(payload) &&
        payload['wallet_balance'] != null &&
        (payload['amount'] != null || payload['driver_earnings'] != null)) {
      return true;
    }
    return false;
  }

  bool _matchesRide(Map<String, dynamic> payload) {
    final rideId = (payload['ride_id'] ?? payload['rideId'] ?? payload['id'] ?? '').toString();
    if (rideId.isEmpty) return true;
    return rideId == _flow.rideId;
  }

  void _onRideStateChanged() {
    if (!mounted || !_isOnline || _paymentHandled) return;
    if (_isPaidPayload(_flow.ride)) {
      _onPaymentEvent(_flow.ride);
    }
  }

  void _onPaymentEvent(Map<String, dynamic> payload) {
    if (!_matchesRide(payload) || !_isPaidPayload(payload)) return;
    if (!mounted || _paymentHandled) return;

    final bal = payload['wallet_balance'];
    final earnings = payload['driver_earnings'];
    setState(() {
      _paymentStatus = 'SUCCESS';
      if (bal is num) _walletBalance = bal.toDouble();
      if (earnings is num) _driverEarnings = earnings.toDouble();
    });
    _flow.mergeRide({
      ..._flow.ride,
      'payment_status': 'SUCCESS',
      'status': payload['status'] ?? 'COMPLETED',
      if (bal is num) 'wallet_balance': bal.toDouble(),
      if (earnings is num) 'driver_earnings': earnings.toDouble(),
    });
    if (_isOnline) unawaited(_autoCloseRazorpayRide());
  }

  void _onPaymentFailed(Map<String, dynamic> payload) {
    if (!_matchesRide(payload)) return;
    if (!mounted) return;
    setState(() => _paymentStatus = 'FAILED');
  }

  Future<void> _refresh() async {
    if (_paymentHandled || _closing) return;
    await _flow.mergeFromServer();
    if (!mounted || _paymentHandled) return;

    final ps =
        (_flow.ride['payment_status'] ?? _flow.ride['paymentStatus'] ?? _paymentStatus).toString().toUpperCase();
    final st = _flow.status;
    setState(() {
      _paymentStatus = ps;
      _paymentMode =
          (_flow.ride['payment_mode'] ?? _paymentMode).toString().toUpperCase();
    });

    if (_isOnline && (ps == 'SUCCESS' || ps == 'PAID' || st == 'COMPLETED')) {
      final bal = _flow.ride['wallet_balance'];
      final earnings = _flow.ride['driver_earnings'];
      if (bal is num) _walletBalance = bal.toDouble();
      if (earnings is num) _driverEarnings = earnings.toDouble();
      if (_walletBalance == null) await _loadWalletBalance();
      _onPaymentEvent(_flow.ride);
    }
  }

  Future<void> _loadWalletBalance() async {
    final token = await _flow.requireToken();
    if (token == null) return;
    final wallet = await DriverApi.withToken(token).getWallet();
    if (!mounted || wallet == null) return;
    final data = wallet['data'] is Map ? wallet['data'] as Map : wallet;
    final bal = (data['balance'] as num?)?.toDouble();
    if (bal != null) setState(() => _walletBalance = bal);
  }

  Future<void> _autoCloseRazorpayRide() async {
    if (_paymentHandled || !_isOnline) return;
    _paymentHandled = true;
    _closing = true;
    _pollTimer?.cancel();
    if (mounted) setState(() {});

    final token = await _flow.requireToken();
    if (token != null) {
      // Ensure ride is COMPLETED + wallet/history stored on server.
      if (_flow.status != 'COMPLETED') {
        final complete = await DriverApi.withToken(token).completeRideResult(_flow.rideId);
        if (complete.data is Map) {
          final body = Map<String, dynamic>.from(complete.data as Map);
          final bal = body['wallet_balance'];
          final earned = body['driver_earnings'];
          if (bal is num) _walletBalance = bal.toDouble();
          if (earned is num) _driverEarnings = earned.toDouble();
        }
      }
      if (_walletBalance == null) await _loadWalletBalance();
    }

    final earned = _driverEarnings ?? (_flow.fare * 0.8);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Razorpay paid — ₹${earned.toStringAsFixed(0)} sent to your wallet. Closing ride…',
          ),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    _flow.mergeRide({
      ..._flow.ride,
      'payment_status': 'SUCCESS',
      'status': 'COMPLETED',
      if (_walletBalance != null) 'wallet_balance': _walletBalance,
      if (_driverEarnings != null) 'driver_earnings': _driverEarnings,
    });

    await _navigateToSuccess();
    unawaited(ActiveRideStore.clear());
  }

  Future<void> _navigateToSuccess() async {
    if (!mounted) return;
    try {
      await RideFlowNavigator.go(context, RideFlowRoutes.success);
    } catch (_) {
      _flow.disposeFlow();
      RideFlowNavigator.markFlowEnded();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _cashReceived() async {
    final token = await _flow.requireToken();
    if (token == null) return;
    setState(() => _loading = true);
    final api = DriverApi.withToken(token);
    final cashResult = await api.confirmCashReceivedResult(_flow.rideId);
    if (!mounted) return;

    var ok = cashResult.success ||
        (cashResult.message ?? '').toLowerCase().contains('already') ||
        (cashResult.message ?? '').toLowerCase().contains('completed');

    Map<String, dynamic> body = cashResult.data is Map
        ? Map<String, dynamic>.from(cashResult.data as Map)
        : <String, dynamic>{};

    // Belt-and-suspenders: older backends may only mark payment SUCCESS.
    if (ok && (body['status']?.toString().toUpperCase() != 'COMPLETED')) {
      final complete = await api.completeRideResult(_flow.rideId);
      if (complete.data is Map) {
        body = {...body, ...Map<String, dynamic>.from(complete.data as Map)};
      }
      ok = ok || complete.success ||
          (complete.message ?? '').toLowerCase().contains('already completed');
    }

    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cashResult.message ?? 'Could not confirm cash'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final bal = body['wallet_balance'];
    final earned = body['driver_earnings'];
    if (bal is num) _walletBalance = bal.toDouble();
    if (earned is num) _driverEarnings = earned.toDouble();
    if (_walletBalance == null) await _loadWalletBalance();

    _paymentHandled = true;
    _closing = true;
    _pollTimer?.cancel();
    _flow.mergeRide({
      ..._flow.ride,
      'payment_status': 'SUCCESS',
      'status': 'COMPLETED',
      if (body['fare'] != null) 'fare': body['fare'],
      if (body['actual_distance_km'] != null) 'actual_distance_km': body['actual_distance_km'],
      if (_walletBalance != null) 'wallet_balance': _walletBalance,
      if (_driverEarnings != null) 'driver_earnings': _driverEarnings,
    });
    await _navigateToSuccess();
    unawaited(ActiveRideStore.clear());
  }

  Widget _statusChip() {
    Color bg;
    Color fg;
    if (_paid || _rideClosed) {
      bg = AppColors.greenLight;
      fg = AppColors.greenDark;
    } else if (_paymentStatus == 'FAILED') {
      bg = AppColors.danger.withValues(alpha: 0.1);
      fg = AppColors.danger;
    } else {
      bg = AppColors.warning.withValues(alpha: 0.12);
      fg = AppColors.warning;
    }
    final label = _rideClosed || _paid ? 'SUCCESS' : _paymentStatus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text('Payment status: $label', style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _successSub?.cancel();
    _failedSub?.cancel();
    _completedSub?.cancel();
    _flow.rideNotifier.removeListener(_onRideStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline) return _buildLegacyRazorpayUi();
    return _buildCashUi();
  }

  Widget _buildLegacyRazorpayUi() {
    return PopScope(
      canPop: _paid || _rideClosed || _paymentHandled,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Razorpay Payment'),
          automaticallyImplyLeading: _paid || _rideClosed || _paymentHandled,
          backgroundColor: AppColors.scaffoldDark,
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
                      const Text('Ride amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                        '₹${_flow.fare.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text('Method: Razorpay (Online)'),
                      const SizedBox(height: 8),
                      _statusChip(),
                      if (_walletBalance != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Wallet: ₹${_walletBalance!.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'When the customer pays, money goes to your wallet and this screen closes automatically.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_closing)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.green),
                      SizedBox(height: 12),
                      Text('Payment received — closing ride…', style: TextStyle(color: AppColors.green)),
                    ],
                  ),
                )
              else if (_paymentStatus == 'FAILED')
                Text(
                  'Payment failed. Ask customer to retry Razorpay.',
                  style: TextStyle(color: AppColors.danger),
                  textAlign: TextAlign.center,
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: AppColors.green),
                        SizedBox(height: 12),
                        Text(
                          'Waiting for customer Razorpay payment…',
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashUi() {
    return RideFlowScaffold(
      title: 'Cash Payment',
      bottomButton: rideFlowButton(
        label: 'CASH RECEIVED',
        icon: TaxiIcons.cash,
        onPressed: _loading || _paid || _closing ? null : _cashReceived,
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ride amount', style: TextStyle(fontWeight: FontWeight.w600)),
                Text('₹${_flow.fare.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('Customer: ${_flow.customerName()}'),
                const SizedBox(height: 8),
                _statusChip(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Collect cash, then tap CASH RECEIVED.'),
      ],
    );
  }
}
