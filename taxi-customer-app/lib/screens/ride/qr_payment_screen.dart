import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/ride_models.dart';
import '../../services/ride_service.dart';
import '../../services/socket_service.dart';
import '../../theme/app_theme.dart';

/// Full-screen QR payment — fixed layout, no sheet, no scroll.
class QrPaymentScreen extends StatefulWidget {
  const QrPaymentScreen({super.key});

  @override
  State<QrPaymentScreen> createState() => _QrPaymentScreenState();
}

class _QrPaymentScreenState extends State<QrPaymentScreen> {
  static const String _merchantName = 'Taxi App';
  static const String _upiId = 'taxi.demo@okbank';

  InvoiceModel? _invoice;
  String _rideId = '';
  bool _loading = true;
  String? _error;
  int _secondsLeft = 300;
  Timer? _countdown;
  Timer? _pollTimer;
  void Function(dynamic)? _paymentListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final rideId = args?['rideId']?.toString() ?? '';
    if (rideId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing ride id';
      });
      return;
    }
    _rideId = rideId;
    await _loadInvoice();
    _startCountdown();
    _startPolling();
    _bindSocket();
  }

  Future<void> _loadInvoice() async {
    try {
      final inv = await RideService.getInvoice(_rideId);
      if (!mounted) return;
      if (_isPaid(inv)) {
        _goSuccess(inv);
        return;
      }
      setState(() {
        _invoice = inv;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _isPaid(InvoiceModel inv) =>
      inv.paymentStatus.toUpperCase() == 'SUCCESS' ||
      inv.paymentStatus.toUpperCase() == 'PAID';

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 0) return;
      setState(() => _secondsLeft--);
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_rideId.isEmpty || !mounted) return;
      try {
        final inv = await RideService.getInvoice(_rideId);
        if (_isPaid(inv)) _goSuccess(inv);
      } catch (_) {}
    });
  }

  void _bindSocket() {
    _paymentListener = (data) {
      if (!mounted) return;
      final map = data is Map ? data : null;
      final rid = map?['ride_id']?.toString();
      if (rid != null && rid.isNotEmpty && rid != _rideId) return;
      _loadInvoice();
    };
    SocketService.instance.connect();
    SocketService.instance.onPaymentSuccess(_paymentListener!);
  }

  void _goSuccess(InvoiceModel inv) {
    _countdown?.cancel();
    _pollTimer?.cancel();
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/payment-success',
      arguments: {
        'rideId': _rideId,
        'amount': inv.fare.toStringAsFixed(0),
        'transactionId': _rideId,
        'paymentMethod': 'UPI / QR',
      },
    );
  }

  String get _qrPayload {
    final amount = _invoice?.fare.toStringAsFixed(0) ?? '0';
    return 'upi://pay?pa=$_upiId&pn=${Uri.encodeComponent(_merchantName)}&am=$amount&cu=INR&tn=Ride%20$_rideId';
  }

  String get _timerLabel {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _pollTimer?.cancel();
    final l = _paymentListener;
    if (l != null) SocketService.instance.offPaymentSuccess(l);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
            'Scan & Pay',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppTheme.surface,
          iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final qrSize =
                          (constraints.maxWidth * 0.62).clamp(220.0, 300.0);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        child: Column(
                          children: [
                            Text(
                              _merchantName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${_invoice?.fare.toStringAsFixed(0) ?? '0'}',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ref: $_rideId',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Expires in $_timerLabel',
                              style: const TextStyle(
                                color: AppTheme.primaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.primary,
                                  width: 2,
                                ),
                              ),
                              child: QrImageView(
                                data: _qrPayload,
                                version: QrVersions.auto,
                                size: qrSize,
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              'Open GPay, PhonePe, Paytm or any UPI app\nand scan this code. Do not close until paid.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'UPI: $_upiId',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
