import 'package:flutter/material.dart';
import 'package:taxi_user/presentation/components/taxi_button.dart';
import 'package:taxi_user/theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/images/logo1.png',
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'TAXI APP',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Book. Ride. Arrive.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Welcome',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in or create an account to book your ride',
                      style: TextStyle(color: AppTheme.inkMuted, fontSize: 14),
                    ),
                    const Spacer(),
                    TaxiButton(
                      text: 'SIGN IN',
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                    ),
                    const SizedBox(height: 14),
                    TaxiButton(
                      text: 'CREATE ACCOUNT',
                      isOutlined: true,
                      useGradient: false,
                      color: AppTheme.ink,
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
