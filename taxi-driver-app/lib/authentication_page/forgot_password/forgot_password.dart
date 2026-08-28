import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taxiapp/authentication_page/common/auth_background.dart';
import 'package:taxiapp/authentication_page/forgot_otp/otp.dart';
import 'package:taxiapp/authentication_page/auth_service.dart'
    as taxiappAuthService;
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/taxi_icons.dart';
import 'package:taxiapp/widgets/taxi_loading.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static final _loginInputTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.cardDarkElevated,
    prefixIconColor: AppColors.gold,
    hintStyle: const TextStyle(color: AppColors.textMuted),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppColors.radiusMd,
      borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppColors.radiusMd,
      borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.2)),
    ),
  );

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleContinue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => taxiLoadingOverlay(message: 'Sending code…'),
    );

    // Call API
    final result = await taxiappAuthService.AuthService().sendForgotOtp(email);

    if (!mounted) return;
    Navigator.pop(context); // Close loading indicator

    if (result['success'] == true) {
      final bool isOffline = result['offline'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? 'OTP sent successfully to your email!',
          ),
          backgroundColor: isOffline ? AppColors.warning : AppColors.green,
          duration: Duration(seconds: isOffline ? 8 : 3),
        ),
      );

      // Navigate to OTP verification page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              OtpVerificationPage(isForgotPasswordFlow: true, email: email),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? 'Failed to send OTP. Please try again.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.scaffoldDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Theme(
                data: Theme.of(context).copyWith(inputDecorationTheme: _loginInputTheme),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).maybePop(),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_ios, color: AppColors.gold, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Back',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Forgot Password',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Enter your email address to receive a password reset code',
                        style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Enter your email',
                          prefixIcon: Icon(TaxiIcons.email),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _handleContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppColors.radiusMd,
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
