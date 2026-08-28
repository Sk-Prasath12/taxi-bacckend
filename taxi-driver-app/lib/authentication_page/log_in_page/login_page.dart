import 'package:flutter/material.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/authentication_page/common/auth_background.dart';
import 'package:taxiapp/authentication_page/forgot_password/forgot_password.dart';
import 'package:taxiapp/authentication_page/rigester_page/register_page.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/taxi_icons.dart';
import 'package:taxiapp/customer/customer_login_page.dart';
import 'package:taxiapp/widgets/taxi_loading.dart';

class LoginPage extends StatefulWidget {
  final AuthService authService;

  const LoginPage({super.key, required this.authService});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  static final _loginInputTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.cardDarkElevated,
    prefixIconColor: AppColors.gold,
    labelStyle: const TextStyle(color: AppColors.gold),
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
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final success = await widget.authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.authService.lastError ?? 'Login failed.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 120, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Taxi Driver',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to start earning',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: AppColors.radiusLg,
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(inputDecorationTheme: _loginInputTheme),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Welcome back',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Enter your driver credentials',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(TaxiIcons.email),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Enter email';
                                if (!v.contains('@')) return 'Invalid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(TaxiIcons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? TaxiIcons.visibility : TaxiIcons.visibilityOff,
                                    color: AppColors.gold,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                                ),
                                child: const Text('Forgot password?', style: TextStyle(color: AppColors.green)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.green,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppColors.green.withValues(alpha: 0.4),
                                  shape: RoundedRectangleBorder(borderRadius: AppColors.radiusMd),
                                ),
                                child: _loading
                                    ? const TaxiLoader(size: 24, color: Colors.white)
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'SIGN IN',
                                            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(TaxiIcons.arrowForward, size: 20),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('New driver? ', style: TextStyle(color: AppColors.textSecondary)),
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RegisterPage(authService: widget.authService),
                                    ),
                                  ),
                                  child: const Text('Create account', style: TextStyle(color: AppColors.green)),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CustomerLoginPage()),
                              ),
                              child: const Text(
                                'Book a ride as customer',
                                style: TextStyle(color: AppColors.gold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
