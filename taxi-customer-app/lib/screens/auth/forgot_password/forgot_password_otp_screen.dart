import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taxi_user/presentation/components/taxi_button.dart';
import 'package:taxi_user/services/auth_service.dart';

class ForgotPasswordOtpScreen extends StatefulWidget {
  const ForgotPasswordOtpScreen({super.key});

  @override
  State<ForgotPasswordOtpScreen> createState() => _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> {
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  String _email = '';
  String? _error;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    _email = args?['email']?.toString() ?? '';
  }

  @override
  void dispose() {
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String get _otpValue => _otpControllers.map((c) => c.text).join();

  void _onOtpChanged(int index, String value) {
    if (value.length > 1) {
      final digit = value.substring(value.length - 1);
      _otpControllers[index].text = digit;
      _otpControllers[index].selection = const TextSelection.collapsed(offset: 1);
    }
    if (value.isNotEmpty && index < _otpFocusNodes.length - 1) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _onVerifyOtp() async {
    if (_loading) return;
    final otp = _otpValue.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _error = 'Please enter a valid 6-digit OTP');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    final result = await AuthService.verifyForgotPasswordOtp(email: _email, otp: otp);
    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pushNamed(
        context,
        '/forgot-password-set-password',
        arguments: {'email': _email},
      );
    } else {
      final message = (result['message'] ?? 'Failed to verify OTP').toString();
      setState(() => _error = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }

    if (mounted) setState(() => _loading = false);
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 44,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        enabled: !_loading,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.black),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFDB813), width: 2),
          ),
        ),
        onChanged: (value) => _onOtpChanged(index, value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Verify OTP',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter the 6-digit code sent to $_email',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 50),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: List.generate(6, _buildOtpBox),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: Colors.red.shade600, fontSize: 13)),
            ],
            const SizedBox(height: 40),
            TaxiButton(
              text: _loading ? 'VERIFYING...' : 'VERIFY OTP',
              color: const Color(0xFFFDB813),
              textColor: Colors.black,
              onPressed: _loading ? () {} : _onVerifyOtp,
            ),
          ],
        ),
      ),
    );
  }
}
