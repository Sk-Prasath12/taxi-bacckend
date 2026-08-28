import 'dart:async';

import 'package:flutter/material.dart';

import '../../../authentication/login/login_screen.dart';
import '../../../config/production_config_guard.dart';
import '../../../presentation/components/app_loading.dart';
import '../../../services/customer_auth_manager.dart';
import '../../../theme/app_theme.dart';
import 'app_bootstrap_screen.dart';

/// Picks login or session restore. Always reaches login within a few seconds.
class AppStartScreen extends StatefulWidget {
  const AppStartScreen({super.key});

  @override
  State<AppStartScreen> createState() => _AppStartScreenState();
}

class _AppStartScreenState extends State<AppStartScreen> {
  static const _maxSplash = Duration(seconds: 3);

  Widget? _screen;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _fallbackTimer = Timer(_maxSplash, _showLoginIfStillLoading);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  void _showLoginIfStillLoading() {
    if (!mounted || _screen != null) return;
    setState(() => _screen = const LoginScreen());
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _resolve() async {
    if (startupConfigWarning != null) {
      _fallbackTimer?.cancel();
      if (!mounted) return;
      setState(() => _screen = const LoginScreen());
      return;
    }

    try {
      final hasSession = await CustomerAuthManager.isAuthenticated().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
      _fallbackTimer?.cancel();
      if (!mounted) return;
      setState(
        () => _screen = hasSession
            ? const AppBootstrapScreen()
            : const LoginScreen(),
      );
    } catch (_) {
      _fallbackTimer?.cancel();
      if (!mounted) return;
      setState(() => _screen = const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _screen ?? const _ColdStartSplash();
  }
}

class _ColdStartSplash extends StatelessWidget {
  const _ColdStartSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Image.asset('assets/images/logo1.png', height: 90),
              ),
              const SizedBox(height: 28),
              const Text(
                'TAXI APP',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 32),
              const AppLoading(size: 52, message: 'Loading…'),
            ],
          ),
        ),
      ),
    );
  }
}
