import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:taxiapp/api/customer_api.dart';
import 'package:taxiapp/customer/customer_auth_service.dart';

class CustomerPaymentPage extends StatefulWidget {
  final String rideId;
  final double amount;
  const CustomerPaymentPage({super.key, required this.rideId, required this.amount});

  @override
  State<CustomerPaymentPage> createState() => _CustomerPaymentPageState();
}

class _CustomerPaymentPageState extends State<CustomerPaymentPage> {
  late Razorpay _razorpay;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternal);
    _createOrderAndOpen();
  }

  Future<void> _createOrderAndOpen() async {
    if (_processing) return;
    setState(() => _processing = true);
    final token = CustomerAuthService().token;
    final order = await CustomerApi.withToken(token).createPaymentOrder(widget.rideId);
    if (order == null || order['success'] != true || order['order_id'] == null) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(order?['message']?.toString() ?? 'Failed to create payment order')),
      );
      return;
    }
    final amountPaise = (order['amount'] as num?)?.toInt();
    final amountRupees = (amountPaise ?? 0) / 100;
    if (amountRupees <= 0) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid fare (₹0). Cannot open Razorpay.')),
      );
      return;
    }
    final options = {
      'key': order['key'] ?? '',
      'amount': amountPaise ?? (amountRupees * 100).round(),
      'currency': order['currency'] ?? 'INR',
      'name': 'TaxiApp',
      'description': 'Ride ${widget.rideId}',
      'order_id': order['order_id'],
      'prefill': {'contact': '', 'email': ''},
      'theme': {'color': '#F37254'}
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout error: $e')));
      }
    }
    if (mounted) setState(() => _processing = false);
  }

  void _handleSuccess(PaymentSuccessResponse resp) async {
    final token = CustomerAuthService().token;
    if (token == null) return;
    final verified = await CustomerApi.withToken(token).verifyPayment(
      rideId: widget.rideId,
      orderId: resp.orderId ?? '',
      paymentId: resp.paymentId ?? '',
      signature: resp.signature ?? '',
    );
    if (!mounted) return;
    if (verified == true) {
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment verification failed')));
  }

  void _handleError(PaymentFailureResponse resp) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment failed')));
  }

  void _handleExternal(ExternalWalletResponse resp) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('External wallet: ${resp.walletName}')));
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pay ₹${widget.amount.toStringAsFixed(0)}')),
      body: Center(
        child: _processing
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _createOrderAndOpen,
                child: Text('Pay ₹${widget.amount.toStringAsFixed(0)} now'),
              ),
      ),
    );
  }
}
