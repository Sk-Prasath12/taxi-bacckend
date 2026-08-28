import 'package:flutter/material.dart';

import '../../../services/customer_auth_manager.dart';
import '../../../services/ride_service.dart';
import '../../../services/session_bootstrap.dart';
import '../../../services/startup_router.dart';
import '../../../domain/services/auth_storage.dart';
import '../../../authentication/login/login_screen.dart';
import '../../../presentation/components/app_loading.dart';
import '../../../theme/app_theme.dart';

/// App entry: restore session, validate tokens, route to home or active ride.
class AppBootstrapScreen extends StatefulWidget {
  const AppBootstrapScreen({super.key});

  @override
  State<AppBootstrapScreen> createState() => _AppBootstrapScreenState();
}

class _AppBootstrapScreenState extends State<AppBootstrapScreen> {
  static const _bootstrapTimeout = Duration(seconds: 8);

  String _status = 'Starting…';
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await _runBootstrap().timeout(
        _bootstrapTimeout,
        onTimeout: () async {
          if (!mounted) return;
          _goLogin();
        },
      );
    } catch (_) {
      if (!mounted) return;
      final stillLoggedIn = await CustomerAuthManager.isAuthenticated();
      if (stillLoggedIn) {
        await CustomerAuthManager.restoreUserFromStorage();
        if (!mounted) return;
        _goHome();
        return;
      }
      _goLogin();
    }
  }

  Future<void> _runBootstrap() async {
    setState(() => _status = 'Restoring your session…');

    final hasSession = await CustomerAuthManager.isAuthenticated();
    if (!hasSession) {
      _goLogin();
      return;
    }

    final valid = await CustomerAuthManager.bootstrapSession();
    if (!mounted) return;
    if (!valid) {
      _goLogin();
      return;
    }

    if (!mounted) return;
    setState(() => _status = 'Loading your profile…');
    await CustomerAuthManager.restoreUserFromStorage();

    final token = await AuthStorage.getAccessToken();
    final email = await AuthStorage.getUserEmail();
    final name = await AuthStorage.getUserName();
    if (token != null && email != null) {
      try {
        await SessionBootstrap.afterLogin(
          token: token,
          email: email,
          displayName: name,
        ).timeout(const Duration(seconds: 8));
      } catch (_) {
        // Non-blocking — home still works without socket/FCM sync.
      }
    }

    if (!mounted) return;
    setState(() => _status = 'Checking active ride…');

    Map<String, dynamic>? activeRide;
    try {
      activeRide = await RideService.getActiveRide();
      if (activeRide != null && activeRide.isNotEmpty) {
        final rideId = (activeRide['ride_id'] ?? '').toString();
        if (rideId.isNotEmpty) {
          await RideService.cacheActiveRide(activeRide);
        }
      }
    } catch (_) {
      // Fall through to home if active ride fetch fails.
    }

    if (!mounted) return;
    final destination = StartupRouter.fromActiveRide(activeRide);
    _goRoute(destination.route, arguments: destination.arguments);
  }

  void _goLogin() {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _goRoute(String route, {Map<String, dynamic>? arguments}) {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.pushReplacementNamed(
      context,
      route,
      arguments: arguments,
    );
  }

  void _goHome() {
    _goRoute('/home');
  }

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
              const AppLoading(size: 52),
              const SizedBox(height: 16),
              Text(
                _status,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
