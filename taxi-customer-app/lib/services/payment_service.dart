import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../config/env_config.dart';
import 'customer_session_store.dart';
import 'ride_service.dart';

/// UPI app package names for intent-based payment.
class UpiApp {
  static const gpay = 'com.google.android.apps.nbu.paisa.user';
  static const phonepe = 'com.phonepe.app';
  static const paytm = 'net.one97.paytm';
}

class RazorpayPaymentResult {
  final String paymentId;
  final String orderId;
  final String status;

  const RazorpayPaymentResult({
    required this.paymentId,
    required this.orderId,
    this.status = 'SUCCESS',
  });
}

class PaymentService {
  final Razorpay _razorpay = Razorpay();
  String? _activeRideId;
  String? _activeOrderId;
  void Function(RazorpayPaymentResult)? _onSuccess;
  void Function(String)? _onError;

  PaymentService() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET,
        (ExternalWalletResponse response) {
      _log('External wallet: ${response.walletName}');
    });
  }

  static void _log(String msg) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[Razorpay] $msg');
    }
  }

  void dispose() {
    _razorpay.clear();
  }

  Future<void> _handleSuccess(PaymentSuccessResponse response) async {
    final rideId = _activeRideId;
    final onSuccess = _onSuccess;
    final onError = _onError;
    if (rideId == null || onSuccess == null || onError == null) return;

    final sigPreview =
        response.signature != null && response.signature!.length > 10
            ? '${response.signature!.substring(0, 10)}...'
            : '${response.signature}';
    _log('✅ PAYMENT SUCCESS paymentId=${response.paymentId} '
        'orderId=${response.orderId} signature=$sigPreview');
    try {
      _log('Verifying payment with backend rideId=$rideId');
      await RideService.verifyPayment(
        rideId: rideId,
        orderId: response.orderId ?? _activeOrderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
      );
      _log('✅ Backend verification complete');
      onSuccess(RazorpayPaymentResult(
        paymentId: response.paymentId ?? '',
        orderId: response.orderId ?? _activeOrderId ?? '',
        status: 'SUCCESS',
      ));
    } catch (e) {
      _log('❌ Backend verification FAILED: $e');
      onError('Payment received but verification failed: $e');
    }
  }

  void _handleError(PaymentFailureResponse response) {
    final msg = response.message ?? 'Payment failed. Please try again.';
    _log('❌ PAYMENT ERROR code=${response.code} message=$msg');
    _onError?.call(msg);
  }

  Future<void> startPayment({
    required String rideId,
    required void Function(RazorpayPaymentResult result) onSuccess,
    required Function(String) onError,
    String? preferredMethod,
    String? methodFilter,
  }) async {
    _activeRideId = rideId;
    _onSuccess = onSuccess;
    _onError = onError;

    try {
      _log('Creating payment order for ride=$rideId');
      final order = await RideService.createPaymentOrder(rideId);
      _activeOrderId = order.orderId;
      _log('Order created: orderId=${order.orderId} amount=${order.amount} '
          'currency=${order.currency} key=${order.key}');

      // Use key from backend, fallback to env config
      final razorpayKey =
          order.key.isNotEmpty ? order.key : EnvConfig.razorpayKeyId;
      _log(
          'Using Razorpay key=$razorpayKey (from ${order.key.isNotEmpty ? 'backend' : 'env'})');

      if (razorpayKey.isEmpty) {
        throw Exception('Razorpay key not configured. '
            'Payment is not configured. Contact support.');
      }
      if (razorpayKey.startsWith('rzp_test_Your') ||
          razorpayKey.contains('YourKeyId')) {
        _log('⚠️ WARNING: Using placeholder Razorpay key! '
            'Get real keys from https://dashboard.razorpay.com/app/keys');
      }
      if (order.orderId.isEmpty || order.amount <= 0) {
        throw Exception(
            'Invalid payment order from server (orderId=${order.orderId}, amount=${order.amount}).');
      }

      final session = await CustomerSessionStore.loadSession() ?? {};
      final prefill = <String, String>{
        if ((session['email'] ?? '').toString().isNotEmpty)
          'email': session['email'].toString(),
        if ((session['phone'] ?? '').toString().isNotEmpty)
          'contact': session['phone'].toString(),
        if ((session['name'] ?? '').toString().isNotEmpty)
          'name': session['name'].toString(),
      };

      final options = <String, dynamic>{
        'key': razorpayKey,
        'amount': order.amount,
        'order_id': order.orderId,
        'currency': order.currency.isNotEmpty
            ? order.currency
            : EnvConfig.razorpayCurrency,
        'name': 'Taxi App',
        'description': 'Ride payment – $rideId',
        'timeout': 300,
        'theme': {'color': '#2563EB'},
        if (prefill.isNotEmpty) 'prefill': prefill,
        'notes': {'ride_id': rideId},
        'method': _buildMethodMap(methodFilter),
        if (preferredMethod != null && preferredMethod != 'netbanking')
          'upi': {
            'flow': 'intent',
            if (preferredMethod == 'gpay') 'app': UpiApp.gpay,
            if (preferredMethod == 'phonepe') 'app': UpiApp.phonepe,
            if (preferredMethod == 'paytm') 'app': UpiApp.paytm,
          },
        if (EnvConfig.isRazorpayLive)
          'readonly': {'email': true, 'contact': true},
      };

      _log('Opening checkout:\n'
          '  key=$razorpayKey\n'
          '  order_id=${order.orderId}\n'
          '  amount=${order.amount} (${order.currency})\n'
          '  amount_in_rupees=₹${(order.amount / 100).toStringAsFixed(2)}\n'
          '  preferredMethod=$preferredMethod\n'
          '  live=${EnvConfig.isRazorpayLive}\n'
          '  prefill=$prefill\n'
          '  options=$options');

      _razorpay.open(options);
    } catch (e) {
      _log('❌ Setup error: $e');
      onError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Test-mode payment: creates a real backend order, then verifies with dev bypass
  /// (backend `ENABLE_PAYMENT_DEV_BYPASS=true`). Works on web and without Razorpay SDK.
  Future<void> processDummyPayment({
    required String rideId,
    required void Function(RazorpayPaymentResult result) onSuccess,
    required Function(String) onError,
  }) async {
    _activeRideId = rideId;
    _onSuccess = onSuccess;
    _onError = onError;

    try {
      _log('Dummy Razorpay: creating order for ride=$rideId');
      final order = await RideService.createPaymentOrder(rideId);
      _activeOrderId = order.orderId;
      if (order.orderId.isEmpty) {
        throw Exception('Server returned empty order id');
      }

      await Future.delayed(const Duration(seconds: 2));

      final paymentId = 'dummy_pay_${DateTime.now().millisecondsSinceEpoch}';
      _log('Dummy Razorpay: verifying orderId=${order.orderId} paymentId=$paymentId');
      await RideService.verifyPayment(
        rideId: rideId,
        orderId: order.orderId,
        paymentId: paymentId,
        signature: 'test_sig',
      );

      onSuccess(RazorpayPaymentResult(
        paymentId: paymentId,
        orderId: order.orderId,
        status: 'SUCCESS',
      ));
    } catch (e) {
      _log('❌ Dummy payment failed: $e');
      onError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Builds the Razorpay `method` map.
  /// When [filter] is 'card', only card is enabled.
  /// When [filter] is 'netbanking', only netbanking is enabled.
  /// Otherwise all methods are enabled.
  static Map<String, dynamic> _buildMethodMap(String? filter) {
    switch (filter) {
      case 'card':
        return {
          'upi': false,
          'card': true,
          'netbanking': false,
          'wallet': false,
          'emi': false,
        };
      case 'netbanking':
        return {
          'upi': false,
          'card': false,
          'netbanking': true,
          'wallet': false,
          'emi': false,
        };
      default:
        return {
          'upi': true,
          'card': true,
          'netbanking': true,
          'wallet': true,
          'emi': false,
        };
    }
  }
}
