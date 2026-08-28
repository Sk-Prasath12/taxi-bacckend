import 'package:flutter/material.dart';
import 'package:taxi_user/presentation/components/app_screen_header.dart';
import 'package:taxi_user/presentation/components/taxi_button.dart';
import 'package:taxi_user/presentation/components/taxi_text_field.dart';
import 'package:taxi_user/services/auth_service.dart';
import 'package:taxi_user/theme/app_theme.dart';

class ForgotPasswordEmailScreen extends StatefulWidget {
  const ForgotPasswordEmailScreen({super.key});

  @override
  State<ForgotPasswordEmailScreen> createState() =>
      _ForgotPasswordEmailScreenState();
}

class _ForgotPasswordEmailScreenState extends State<ForgotPasswordEmailScreen> {
  final _emailController = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSendOtp() async {
    if (_loading) return;
    final email = _emailController.text.trim().toLowerCase();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    final result = await AuthService.sendForgotPasswordOtp(email: email);
    if (!mounted) return;

    if (result['success'] == true) {
      final data = result['data'];
      final otpFromApi =
          data is Map ? data['otp']?.toString().trim() : null;
      Navigator.pushNamed(
        context,
        '/otp-verification',
        arguments: {
          'flow': 'forgot-password',
          'identity': email,
          if (otpFromApi != null && otpFromApi.isNotEmpty) 'otp': otpFromApi,
        },
      );
    } else {
      final message = (result['message'] ?? 'Failed to send OTP').toString();
      setState(() => _error = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
      );
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppScreenHeader(
            title: 'Forgot password',
            subtitle: 'Enter your email to receive a verification code',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TaxiTextField(
                    label: 'Email address',
                    hint: 'you@example.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    controller: _emailController,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: AppTheme.danger, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 32),
                  TaxiButton(
                    text: _loading ? 'Sending...' : 'SEND OTP',
                    onPressed: _loading ? () {} : _onSendOtp,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
