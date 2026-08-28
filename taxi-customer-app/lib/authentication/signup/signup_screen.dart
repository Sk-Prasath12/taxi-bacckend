import 'package:flutter/material.dart';
import 'package:taxi_user/presentation/components/app_screen_header.dart';
import 'package:taxi_user/presentation/components/taxi_button.dart';
import 'package:taxi_user/presentation/components/taxi_text_field.dart';
import 'package:taxi_user/services/auth_service.dart';
import 'package:taxi_user/theme/app_theme.dart';

/// Sign-up screen — registration form.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_loading) return;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || phone.isEmpty || email.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }
    final phoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phoneDigits.length < 8 || phoneDigits.length > 15) {
      setState(() => _error = 'Please enter a valid phone number');
      return;
    }
    setState(() { _error = null; _loading = true; });
    final result = await AuthService.register(name: name, email: email, phone: phone);
    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'];
      final otpFromApi =
          data is Map ? data['otp']?.toString().trim() : null;
      Navigator.pushNamed(
        context,
        '/otp-verification',
        arguments: {
          'flow': 'signup',
          'identity': email.trim().toLowerCase(),
          'name': name,
          'phone': phone,
          if (otpFromApi != null && otpFromApi.isNotEmpty) 'otp': otpFromApi,
        },
      );
    } else {
      final message = (result['message'] ?? 'Registration failed').toString();
      setState(() => _error = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
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
            title: 'Create Account',
            subtitle: 'Fill in your details to get started',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TaxiTextField(
                    label: 'Full Name',
                    prefixIcon: Icons.person_outline_rounded,
                    controller: _nameController,
                  ),
                  const SizedBox(height: 20),
                  TaxiTextField(
                    label: 'Phone Number',
                    hint: '+91 98765 43210',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    controller: _phoneController,
                  ),
                  const SizedBox(height: 20),
                  TaxiTextField(
                    label: 'Email Address',
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
                    text: _loading ? 'Sending OTP...' : 'CONTINUE',
                    onPressed: _loading ? () {} : () => _onSubmit(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account? '),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/login'),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: AppTheme.primaryDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
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
