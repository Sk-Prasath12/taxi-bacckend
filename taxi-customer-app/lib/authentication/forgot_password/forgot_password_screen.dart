import 'package:flutter/material.dart';
import 'package:taxi_user/presentation/components/app_screen_header.dart';
import 'package:taxi_user/presentation/components/taxi_button.dart';
import 'package:taxi_user/presentation/components/taxi_text_field.dart';
import 'package:taxi_user/services/auth_service.dart';
import 'package:taxi_user/theme/app_theme.dart';

/// Forgot-password — sends OTP, then shared OTP verification screen.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final identity = args['identity']?.toString().trim() ?? '';
      if (identity.isNotEmpty) {
        _controller.text = identity;
        _prefilled = true;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final value = _controller.text.trim().toLowerCase();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(value)) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final result = await AuthService.sendForgotPasswordOtp(email: value);
      if (result['success'] != true) {
        throw Exception(result['message']?.toString() ?? 'Failed to send OTP');
      }
      if (!mounted) return;
      final data = result['data'];
      final otpFromApi =
          data is Map ? data['otp']?.toString().trim() : null;
      Navigator.pushNamed(
        context,
        '/otp-verification',
        arguments: {
          'flow': 'forgot-password',
          'identity': value,
          if (otpFromApi != null && otpFromApi.isNotEmpty) 'otp': otpFromApi,
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error ?? 'Failed to send OTP'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            subtitle: 'We will email you a 6-digit verification code',
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
                    hint: 'Enter your email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    controller: _controller,
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
                    onPressed: _loading ? () {} : _sendOtp,
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
