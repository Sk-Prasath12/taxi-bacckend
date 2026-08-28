import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/env_config.dart';
import '../../models/ride_models.dart';
import '../../services/payment_service.dart';
import '../../services/ride_service.dart';
import '../../services/ride_session_cleanup.dart';

class RideInvoiceScreen extends StatefulWidget {
  const RideInvoiceScreen({super.key});

  @override
  State<RideInvoiceScreen> createState() => _RideInvoiceScreenState();
}

class _RideInvoiceScreenState extends State<RideInvoiceScreen> {
  static const String _demoUpiId = 'taxi.demo@okbank';
  static const String _demoBankName = 'Example Bank';
  static const String _demoAccountMasked = 'XXXXXX7821';
  final PaymentService _paymentService = PaymentService();
  bool _loading = true;
  bool _processingPayment = false;
  String? _error;
  InvoiceModel? _invoice;
  String _rideId = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
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
      final data = await RideService.getInvoice(rideId);
      if (!mounted) return;
      setState(() => _invoice = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onDonePressed() async {
    if (_processingPayment || _loading || _invoice == null) return;
    if (_isOnlinePaymentLocked) {
      await _startPaymentFlow();
      return;
    }
    if (!mounted) return;
    await _navigateHomeAfterRide();
  }

  Future<void> _startPaymentFlow() async {
    if (_rideId.isEmpty) return;
    print('PAYMENT BUTTON CLICKED');
    setState(() => _processingPayment = true);

    final useDummy = EnvConfig.useDummyRazorpay;
    final paymentFn = useDummy
        ? _paymentService.processDummyPayment
        : _paymentService.startPayment;

    await paymentFn(
      rideId: _rideId,
      onSuccess: (result) {
        if (!mounted) return;
        setState(() => _processingPayment = false);
        Navigator.pushReplacementNamed(
          context,
          '/payment-success',
          arguments: {
            'rideId': _rideId,
            'amount': _invoice?.fare.toStringAsFixed(0) ?? '0',
            'paymentId': result.paymentId,
            'orderId': result.orderId,
            'transactionId': result.paymentId,
            'paymentMethod': useDummy ? 'Razorpay (Test)' : 'Razorpay',
            'status': result.status,
          },
        );
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => _processingPayment = false);
        Navigator.pushNamed(
          context,
          '/payment-failed',
          arguments: {
            'rideId': _rideId,
            'amount': _invoice?.fare.toStringAsFixed(0) ?? '0',
            'paymentMethod': 'Razorpay',
            'errorMessage': message,
            'status': 'FAILED',
          },
        );
      },
    );
  }

  bool get _isOnlinePending =>
      _invoice != null &&
      _invoice!.paymentMode.toUpperCase() == 'ONLINE' &&
      _invoice!.paymentStatus.toUpperCase() == 'PENDING';

  Future<void> _navigateHomeAfterRide() async {
    await RideSessionCleanup.resetForNewSession();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
      arguments: {
        'lastRideStatus': 'COMPLETED',
        'rideId': _rideId,
      },
    );
  }

  bool get _isOnlinePaymentLocked =>
      _invoice != null &&
      _invoice!.paymentMode.toUpperCase() == 'ONLINE' &&
      _invoice!.paymentStatus.toUpperCase() != 'SUCCESS';

  String get _upiQrData {
    final amount = _invoice?.fare.toStringAsFixed(0) ?? '0';
    return 'upi://pay?pa=$_demoUpiId&pn=Taxi%20App&am=$amount&cu=INR&tn=Ride%20$_rideId';
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isOnlinePaymentLocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please complete payment to continue')),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Invoice'),
          automaticallyImplyLeading: !_isOnlinePaymentLocked,
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _invoice == null
                      ? const Center(child: Text('No invoice found'))
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _line('Pickup', _invoice!.pickupAddress),
                                      _line('Drop', _invoice!.dropAddress),
                                      _line('Distance', '${_invoice!.distance.toStringAsFixed(1)} km'),
                                      _line('Duration', '${_invoice!.duration.toStringAsFixed(0)} min'),
                                      _line('Fare', '₹${_invoice!.fare.toStringAsFixed(0)}'),
                                      _line('Payment Mode', _invoice!.paymentMode),
                                      _line('Payment Status', _invoice!.paymentStatus),
                                      _line('Driver', _invoice!.driverName),
                                    ],
                                  ),
                                ),
                              ),
                              if (_isOnlinePending) ...[
                                const SizedBox(height: 12),
                                Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'UPI / Online payment',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Scan this QR in any UPI app (GPay/PhonePe/Paytm).',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        const SizedBox(height: 12),
                                        Center(
                                          child: QrImageView(
                                            data: _upiQrData,
                                            version: QrVersions.auto,
                                            size: 170,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        _line('UPI ID', _demoUpiId),
                                        _line('Bank', _demoBankName),
                                        _line('Account', _demoAccountMasked),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFDB813),
                                    foregroundColor: Colors.black,
                                  ),
                                  onPressed: _onDonePressed,
                                  child: Text(
                                    _processingPayment
                                        ? 'PROCESSING...'
                                        : (_isOnlinePaymentLocked
                                            ? 'PAY & CLOSE RIDE'
                                            : 'DONE'),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
        ),
      ),
    );
  }

  Widget _line(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(key, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
