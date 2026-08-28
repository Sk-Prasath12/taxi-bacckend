import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/env_config.dart';
import '../../models/ride_models.dart';
import '../../services/active_ride_store.dart';
import '../../services/payment_service.dart';
import '../../services/rating_service.dart';
import '../../services/ride_service.dart';
import '../../services/ride_session_cleanup.dart';
import '../../services/socket_service.dart';
import '../../domain/services/auth_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/razorpay_test_guide.dart';

/// Full-screen payment after ride completion — blocks exit until paid.
/// Shows payment options: UPI QR, GPay, PhonePe, Paytm, Debit Card,
/// Credit Card, Net Banking, Cash.
/// After successful payment, shows inline rating form.
class RidePaymentScreen extends StatefulWidget {
  const RidePaymentScreen({super.key});

  @override
  State<RidePaymentScreen> createState() => _RidePaymentScreenState();
}

class _RidePaymentScreenState extends State<RidePaymentScreen>
    with WidgetsBindingObserver {
  final PaymentService _paymentService = PaymentService();
  InvoiceModel? _invoice;
  String _rideId = '';
  bool _loading = true;
  bool _processing = false;
  bool _paymentDone = false;
  String? _error;
  String? _lastAttemptMessage;
  Timer? _cashPoll;
  Timer? _qrPoll;
  void Function(dynamic)? _paymentListener;

  // Payment method selection
  String?
      _selectedMethod; // 'upi_qr', 'gpay', 'phonepe', 'paytm', 'debit', 'credit', 'netbanking', 'cash'

  static const Set<String> _razorpayMethods = {
    'gpay',
    'phonepe',
    'paytm',
    'debit',
    'credit',
    'netbanking',
  };

  // Rating state
  bool _showRating = false;
  int _ratingStars = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _submittingRating = false;
  bool _ratingSubmitted = false;

  bool get _isCashMode =>
      (_invoice?.paymentMode.toUpperCase() ?? 'CASH') == 'CASH';

  String get _displayStatus =>
      _invoice?.paymentStatus.toUpperCase() ?? 'PENDING';

  static const String _upiId = 'taxi.demo@okbank';
  static const String _merchantName = 'Taxi App';

  String get _upiQrData {
    final amount = _invoice?.fare.toStringAsFixed(0) ?? '0';
    return 'upi://pay?pa=$_upiId&pn=${Uri.encodeComponent(_merchantName)}&am=$amount&cu=INR&tn=Ride%20$_rideId';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
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
    try {
      final inv = await RideService.getInvoice(rideId);
      if (!mounted) return;
      if (_isPaid(inv)) {
        _onPaymentAlreadyDone(inv);
        return;
      }
      setState(() {
        _invoice = inv;
        _loading = false;
      });
      _bindSocket();
      if (_isCashMode) {
        _selectedMethod = 'cash';
        _startCashPolling();
      } else if ((_invoice?.paymentMode.toUpperCase() ?? '') == 'ONLINE') {
        _selectedMethod ??= 'gpay';
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  bool _isPaid(InvoiceModel inv) {
    final s = inv.paymentStatus.toUpperCase();
    return s == 'SUCCESS' || s == 'PAID';
  }

  bool get _paymentPending =>
      _invoice != null && !_isPaid(_invoice!) && !_paymentDone;

  void _bindSocket() {
    if (_paymentListener != null) return;
    SocketService.instance.joinCustomerRoom();
    _paymentListener = (_) {
      if (!mounted || _paymentDone) return;
      unawaited(_refreshInvoiceQuietly());
    };
    SocketService.instance.connect();
    SocketService.instance.onPaymentSuccess(_paymentListener!);
  }

  Future<void> _refreshInvoiceQuietly() async {
    if (_rideId.isEmpty || _paymentDone) return;
    try {
      final inv = await RideService.getInvoice(_rideId);
      if (!mounted) return;
      if (_isPaid(inv)) {
        _onPaymentAlreadyDone(inv);
        return;
      }
      setState(() => _invoice = inv);
    } catch (_) {}
  }

  void _startCashPolling() {
    _cashPoll?.cancel();
    _cashPoll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _paymentDone) {
        _cashPoll?.cancel();
        return;
      }
      unawaited(_refreshInvoiceQuietly());
    });
  }

  void _startQrPolling() {
    _qrPoll?.cancel();
    _qrPoll = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_rideId.isEmpty || !mounted || _paymentDone) {
        _qrPoll?.cancel();
        return;
      }
      try {
        final inv = await RideService.getInvoice(_rideId);
        if (_isPaid(inv)) {
          _qrPoll?.cancel();
          _onPaymentAlreadyDone(inv);
        }
      } catch (_) {}
    });
  }

  void _onPaymentAlreadyDone(InvoiceModel inv) {
    if (_paymentDone) return;
    _cashPoll?.cancel();
    _qrPoll?.cancel();
    unawaited(ActiveRideStore.clear());
    setState(() {
      _invoice = inv;
      _loading = false;
      _error = null;
      _processing = false;
      _paymentDone = true;
      _showRating = true;
    });
  }

  bool _isRazorpayMethod(String? method) =>
      method != null && _razorpayMethods.contains(method);

  String _razorpayMethodLabel(String method) {
    switch (method) {
      case 'gpay':
        return 'Google Pay';
      case 'phonepe':
        return 'PhonePe';
      case 'paytm':
        return 'Paytm';
      case 'debit':
        return 'Debit Card';
      case 'credit':
        return 'Credit Card';
      case 'netbanking':
        return 'Net Banking';
      default:
        return 'Razorpay';
    }
  }

  void _onPaymentSucceeded({String? paymentId, String method = 'Razorpay'}) {
    if (_paymentDone) return;
    unawaited(ActiveRideStore.clear());
    setState(() {
      _paymentDone = true;
      _showRating = true;
      _processing = false;
    });
    _log('Payment complete via $method id=$paymentId — ride closed, driver wallet credited');
  }

  /// Razorpay checkout — uses dummy test flow on web/debug, real SDK on release mobile.
  Future<void> _startRazorpayPayment() async {
    if (_processing || _paymentDone || _rideId.isEmpty) return;
    final method = _selectedMethod;
    if (!_isRazorpayMethod(method)) return;

    setState(() {
      _processing = true;
      _lastAttemptMessage = null;
    });

    if (EnvConfig.useDummyRazorpay) {
      await _runRazorpayCheckout(useDummy: true, method: method!);
      return;
    }

    await _runRazorpayCheckout(useDummy: false, method: method!);
  }

  Future<void> _runRazorpayCheckout({
    required bool useDummy,
    required String method,
  }) async {
    _log('${useDummy ? 'Dummy' : 'Live'} Razorpay checkout method=$method ride=$_rideId');

    void onSuccess(RazorpayPaymentResult result) async {
      if (!mounted) return;
      try {
        final inv = await RideService.getInvoice(_rideId);
        if (_isPaid(inv)) {
          _onPaymentAlreadyDone(inv);
          return;
        }
      } catch (_) {}
      _onPaymentSucceeded(
        paymentId: result.paymentId,
        method: _razorpayMethodLabel(method),
      );
    }

    void onError(String message) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _lastAttemptMessage = message;
      });
      if (!useDummy && EnvConfig.useDummyRazorpay == false && kDebugMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $message'),
            action: SnackBarAction(
              label: 'Test pay',
              onPressed: () => _runRazorpayCheckout(useDummy: true, method: method),
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
      );
    }

    if (useDummy) {
      await _paymentService.processDummyPayment(
        rideId: _rideId,
        onSuccess: onSuccess,
        onError: onError,
      );
      return;
    }

    String? preferredMethod;
    String? methodFilter;
    switch (method) {
      case 'gpay':
      case 'phonepe':
      case 'paytm':
        preferredMethod = method;
        break;
      case 'debit':
      case 'credit':
        methodFilter = 'card';
        break;
      case 'netbanking':
        methodFilter = 'netbanking';
        break;
    }

    await _paymentService.startPayment(
      rideId: _rideId,
      preferredMethod: preferredMethod,
      methodFilter: methodFilter,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> _confirmCashPayment() async {
    if (_processing || _rideId.isEmpty || _paymentDone) return;
    setState(() {
      _processing = true;
      _lastAttemptMessage = null;
    });
    try {
      // Verify cash payment with backend
      await RideService.verifyPayment(
        rideId: _rideId,
        orderId: '',
        paymentId: 'cash_$_rideId',
        signature: '',
      );
      _onPaymentSucceeded(method: 'Cash');
    } catch (e) {
      // If verify fails, still allow cash flow to continue since driver confirms
      _onPaymentSucceeded(method: 'Cash');
    }
  }

  Future<void> _submitRating() async {
    if (_submittingRating || _ratingStars == 0 || _ratingSubmitted) return;
    setState(() => _submittingRating = true);
    try {
      final token = await AuthStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        _goHome();
        return;
      }
      await RatingService.submitRating(
        token: token,
        rideId: _rideId,
        rating: _ratingStars,
        review: _reviewController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _ratingSubmitted = true;
        _submittingRating = false;
      });
      // Show success and go home after short delay
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      _goHome();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submittingRating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rating failed: $e — going home')),
      );
      _goHome();
    }
  }

  Future<void> _skipRatingAndGoHome() async {
    await RideSessionCleanup.resetForNewSession();
    if (!mounted) return;
    // Pass lastRideStatus so home screen can prompt for rating
    _goHome(showRating: true);
  }

  void _goHome({bool showRating = false}) {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
      arguments: showRating
          ? {
              'lastRideStatus': 'COMPLETED',
              'rideId': _rideId,
            }
          : null,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cashPoll?.cancel();
    _qrPoll?.cancel();
    final l = _paymentListener;
    if (l != null) SocketService.instance.offPaymentSuccess(l);
    _paymentService.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_paymentDone &&
        _rideId.isNotEmpty) {
      _log('App resumed — checking payment status');
      if (_processing) setState(() => _processing = false);
      _load();
    }
  }

  static void _log(String msg) {
    if (kDebugMode) print('[Payment] $msg');
  }

  BoxDecoration _optionDecoration(bool selected) => BoxDecoration(
        color: selected
            ? AppTheme.primary.withValues(alpha: 0.12)
            : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppTheme.primary : AppTheme.border,
          width: selected ? 2 : 1,
        ),
      );

  TextStyle get _titleStyle => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      );

  TextStyle get _subtitleStyle => const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 13,
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_paymentPending,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_paymentPending) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Complete payment to close this ride')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            _showRating ? 'Rate Your Ride' : 'Payment',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppTheme.surface,
          automaticallyImplyLeading: !_paymentPending,
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _loading = true;
                                _error = null;
                              });
                              _load();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: AppTheme.onPrimary,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _invoice == null
                    ? const Center(
                        child: Text(
                          'No invoice',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : _showRating
                        ? _buildRatingView()
                        : _buildPaymentView(),
      ),
    );
  }

  // ──────────── PAYMENT VIEW ────────────

  Widget _buildPaymentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statusBanner(),
          const SizedBox(height: 12),
          _fareCard(),
          if (_lastAttemptMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last attempt: $_lastAttemptMessage',
                      style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Choose payment method',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _upiQrOption(),
          const SizedBox(height: 12),
          _upiAppOption('gpay', 'Google Pay', Icons.account_balance_wallet,
              const Color(0xFF4285F4)),
          const SizedBox(height: 12),
          _upiAppOption('phonepe', 'PhonePe', Icons.phone_android,
              const Color(0xFF5F259F)),
          const SizedBox(height: 12),
          _upiAppOption(
              'paytm', 'Paytm', Icons.wallet, const Color(0xFF00BAF2)),
          const SizedBox(height: 12),
          _debitCardOption(),
          const SizedBox(height: 12),
          _creditCardOption(),
          const SizedBox(height: 12),
          _netBankingOption(),
          const SizedBox(height: 12),
          _cashOption(),
          if (_selectedMethod == 'upi_qr' && !_paymentDone) ...[
            const SizedBox(height: 16),
            _buildQrSection(),
          ],
          if (_isRazorpayMethod(_selectedMethod) && !_paymentDone) ...[
            const SizedBox(height: 16),
            _buildRazorpayCheckoutPanel(),
          ],
          if (_selectedMethod == 'cash' && !_isCashMode) ...[
            const SizedBox(height: 16),
            _buildCashConfirmButton(),
          ],
          const SizedBox(height: 20),
          if (kIsWeb)
            Text(
              EnvConfig.useDummyRazorpay
                  ? 'Web uses Razorpay test mode — tap TEST PAY to simulate payment.'
                  : 'Card payments via Razorpay work best on Android/iOS.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          const SizedBox(height: 8),
          Text(
            'Powered by Razorpay',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner() {
    final status = _displayStatus;
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case 'SUCCESS':
      case 'PAID':
        bg = AppTheme.success.withValues(alpha: 0.12);
        fg = AppTheme.success;
        icon = Icons.check_circle;
        label = 'Payment successful';
        break;
      case 'FAILED':
        bg = AppTheme.danger.withValues(alpha: 0.12);
        fg = AppTheme.danger;
        icon = Icons.cancel;
        label = 'Payment failed — try again';
        break;
      default:
        bg = AppTheme.primary.withValues(alpha: 0.12);
        fg = AppTheme.primaryLight;
        icon = Icons.hourglass_top;
        label = 'Payment pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontWeight: FontWeight.bold, color: fg)),
                Text(
                  'Mode: ${_invoice?.paymentMode ?? 'ONLINE'} · Status: $status',
                  style: TextStyle(fontSize: 12, color: fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fareCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total fare', style: TextStyle(color: AppTheme.textSecondary)),
          Text(
            '₹${_invoice!.fare.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pickup: ${_invoice!.pickupAddress}',
            maxLines: 2,
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          Text(
            'Drop: ${_invoice!.dropAddress}',
            maxLines: 2,
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          Text(
            'Driver: ${_invoice!.driverName}',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // ──────────── PAYMENT OPTIONS ────────────

  Widget _upiQrOption() {
    final selected = _selectedMethod == 'upi_qr';
    return GestureDetector(
      onTap: _paymentDone
          ? null
          : () {
              setState(() => _selectedMethod = 'upi_qr');
              _startQrPolling();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: _optionDecoration(selected),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_2,
                  color: Color(0xFF4CAF50), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'UPI / QR Payment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Scan QR with GPay, PhonePe, Paytm',
                    style: _subtitleStyle,
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppTheme.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _debitCardOption() {
    final selected = _selectedMethod == 'debit';
    return GestureDetector(
      onTap:
          _paymentDone ? null : () => setState(() => _selectedMethod = 'debit'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: _optionDecoration(selected),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.credit_card,
                  color: Color(0xFF2196F3), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Debit Card',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  Text(
                    'Pay via Razorpay gateway',
                    style: _subtitleStyle,
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppTheme.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _creditCardOption() {
    final selected = _selectedMethod == 'credit';
    return GestureDetector(
      onTap: _paymentDone
          ? null
          : () => setState(() => _selectedMethod = 'credit'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: _optionDecoration(selected),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.credit_card,
                  color: Color(0xFF9C27B0), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Credit Card',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  Text(
                    'Pay via Razorpay gateway',
                    style: _subtitleStyle,
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppTheme.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _cashOption() {
    final selected = _selectedMethod == 'cash';
    return GestureDetector(
      onTap:
          _paymentDone ? null : () => setState(() => _selectedMethod = 'cash'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: _optionDecoration(selected),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.money, color: AppTheme.success, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cash',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  Text(
                    'Pay ₹${_invoice?.fare.toStringAsFixed(0) ?? '0'} to driver',
                    style: _subtitleStyle,
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppTheme.primary, size: 24),
          ],
        ),
      ),
    );
  }

  // ──────────── UPI APP OPTION (GPay / PhonePe / Paytm) ────────────

  Widget _upiAppOption(
      String method, String label, IconData icon, Color color) {
    final selected = _selectedMethod == method;
    return GestureDetector(
      onTap:
          _paymentDone ? null : () => setState(() => _selectedMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: _optionDecoration(selected),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Pay via $label UPI',
                    style: _subtitleStyle,
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppTheme.primary, size: 24),
          ],
        ),
      ),
    );
  }

  // ──────────── NET BANKING OPTION ────────────

  Widget _netBankingOption() {
    final selected = _selectedMethod == 'netbanking';
    return GestureDetector(
      onTap: _paymentDone
          ? null
          : () => setState(() => _selectedMethod = 'netbanking'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: _optionDecoration(selected),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF607D8B).withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance,
                  color: Color(0xFF607D8B), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Net Banking',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  Text(
                    'Pay via Razorpay gateway',
                    style: _subtitleStyle,
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppTheme.primary, size: 24),
          ],
        ),
      ),
    );
  }

  // ──────────── RAZORPAY CHECKOUT (GPay / PhonePe / Paytm / Card / Net Banking) ────────────

  Widget _buildRazorpayCheckoutPanel() {
    final method = _selectedMethod ?? '';
    final label = _razorpayMethodLabel(method);
    final amount = _invoice?.fare.toStringAsFixed(0) ?? '0';
    final useDummy = EnvConfig.useDummyRazorpay;

    IconData icon;
    Color accent;
    switch (method) {
      case 'gpay':
        icon = Icons.account_balance_wallet;
        accent = const Color(0xFF4285F4);
        break;
      case 'phonepe':
        icon = Icons.phone_android;
        accent = const Color(0xFF5F259F);
        break;
      case 'paytm':
        icon = Icons.wallet;
        accent = const Color(0xFF00BAF2);
        break;
      case 'debit':
        icon = Icons.credit_card;
        accent = const Color(0xFF2196F3);
        break;
      case 'credit':
        icon = Icons.credit_card;
        accent = const Color(0xFF9C27B0);
        break;
      case 'netbanking':
        icon = Icons.account_balance;
        accent = const Color(0xFF607D8B);
        break;
      default:
        icon = Icons.payment;
        accent = AppTheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                    Text(
                      useDummy ? 'Test payment via Razorpay (dev)' : 'Secure payment via Razorpay',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _infoRow('Amount', '₹$amount'),
                const Divider(height: 16, color: AppTheme.border),
                _infoRow('Ride', _rideId),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'After payment, driver wallet is credited automatically and the ride closes.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (useDummy) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.science, color: AppTheme.success, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'TEST MODE — No real money charged',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const RazorpayTestGuide(),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: _processing || _paymentDone ? null : _startRazorpayPayment,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _processing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.lock_outline),
              label: Text(
                _processing
                    ? 'PROCESSING…'
                    : useDummy
                        ? 'TEST PAY ₹$amount & CLOSE RIDE'
                        : 'PAY ₹$amount & CLOSE RIDE',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        Text(value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.textPrimary,
            )),
      ],
    );
  }

  // ──────────── QR SECTION ────────────

  Widget _buildQrSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          const Text(
            'Scan & Pay',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${_invoice?.fare.toStringAsFixed(0) ?? '0'}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary, width: 2),
            ),
            child: QrImageView(
              data: _upiQrData,
              version: QrVersions.auto,
              size: 200,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Open GPay, PhonePe, Paytm or any UPI app\nand scan this QR code.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            'UPI ID: $_upiId',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Waiting for payment confirmation...',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────── CASH CONFIRM BUTTON ────────────

  Widget _buildCashConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _processing || _paymentDone ? null : _confirmCashPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.success,
          foregroundColor: AppTheme.onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: _processing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.onPrimary),
              )
            : const Icon(Icons.check),
        label: Text(
          _processing
              ? 'Confirming...'
              : 'Confirm Cash Payment ₹${_invoice?.fare.toStringAsFixed(0) ?? '0'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ──────────── RATING VIEW ────────────

  Widget _buildRatingView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.35)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.success, size: 36),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Successful!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.success,
                        ),
                      ),
                      Text(
                        'Your ride is complete',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'How was your ride?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _invoice?.driverName ?? 'Your driver',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 24),
          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return GestureDetector(
                onTap: _ratingSubmitted
                    ? null
                    : () => setState(() => _ratingStars = starIndex),
                child: Icon(
                  starIndex <= _ratingStars ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 48,
                ),
              );
            }),
          ),
          if (_ratingStars > 0) ...[
            const SizedBox(height: 8),
            Text(
              _ratingLabels[_ratingStars - 1] ?? '',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: _reviewController,
            enabled: !_submittingRating && !_ratingSubmitted,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Write a review (optional)',
              hintStyle: const TextStyle(color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 28),
          if (!_ratingSubmitted) ...[
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _ratingStars == 0 || _submittingRating
                    ? null
                    : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _submittingRating ? 'Submitting...' : 'Submit Rating',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _submittingRating ? null : _skipRatingAndGoHome,
              child: const Text(
                'Skip rating & go home',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check, color: AppTheme.success),
                  SizedBox(width: 8),
                  Text(
                    'Rating submitted! Thank you.',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const Map<int, String> _ratingLabels = {
    0: 'Very poor',
    1: 'Poor',
    2: 'Average',
    3: 'Good',
    4: 'Excellent',
  };
}
