import 'package:flutter/material.dart';
import 'package:taxi_user/config/production_config_guard.dart';
import 'package:taxi_user/presentation/components/app_loading.dart';
import 'package:taxi_user/presentation/components/app_screen_header.dart';
import 'package:taxi_user/presentation/components/taxi_button.dart';
import 'package:taxi_user/presentation/components/taxi_text_field.dart';
import 'package:taxi_user/services/auth_service.dart';
import 'package:taxi_user/services/customer_session_store.dart';
import 'package:taxi_user/services/ride_session_cleanup.dart';
import 'package:taxi_user/services/session_bootstrap.dart';
import 'package:taxi_user/theme/app_theme.dart';

/// Sign-in screen — email + password via customer API.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final warning = startupConfigWarning;
    if (warning != null && warning.isNotEmpty) {
      _error = warning;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefillSavedEmail();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && _emailController.text.isEmpty) {
      final email = args['email']?.toString();
      if (email != null && email.isNotEmpty) {
        _emailController.text = email;
      }
    }
  }

  Future<void> _prefillSavedEmail() async {
    if (_emailController.text.isNotEmpty) return;
    final saved = await CustomerSessionStore.getLastLoginEmail();
    if (saved != null && saved.isNotEmpty && mounted) {
      _emailController.text = saved;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (_loading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required');
      return;
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    final result = await AuthService.login(email: email, password: password);
    if (!mounted) return;

    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>?;
      final token = data?['token']?.toString();
      if (token == null || token.isEmpty) {
        setState(() => _error = 'Login failed: no token from server');
      } else {
        final user = data?['user'];
        final name = user is Map ? user['name']?.toString() : null;
        final userEmail = user is Map ? user['email']?.toString() : email;
        final refreshToken = data?['refreshToken']?.toString();
        await SessionBootstrap.afterLogin(
          token: token,
          email: userEmail ?? email,
          displayName: name,
          refreshToken: refreshToken,
          user: user is Map ? Map<String, dynamic>.from(user) : null,
          context: context,
        );
        if (!mounted) return;
        await RideSessionCleanup.resetForNewSession();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } else {
      final message = (result['message'] ?? 'Login failed').toString();
      setState(() => _error = message);
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return PopScope(
      canPop: canPop,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Stack(
        children: [
          Column(
            children: [
              AppScreenHeader(
                title: 'Sign In',
                subtitle: 'Welcome back — enter your credentials',
                onBack: canPop ? () => Navigator.pop(context) : null,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TaxiTextField(
                        label: 'Email Address',
                        hint: 'Enter your email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        controller: _emailController,
                      ),
                      const SizedBox(height: 16),
                      TaxiTextField(
                        label: 'Password',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        onSuffixTap: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        controller: _passwordController,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/forgot-password-email'),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: AppTheme.primaryLight,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TaxiButton(
                        text: 'SIGN IN',
                        loading: _loading,
                        onPressed: _onContinue,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account? "),
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushReplacementNamed(context, '/signup'),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: AppTheme.primaryLight,
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
          if (_loading)
            const AppLoadingOverlay(message: 'Signing you in…'),
        ],
        ),
      ),
    );
  }
}
