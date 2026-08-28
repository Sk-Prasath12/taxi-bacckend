import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import '../../../authentication_page/auth_service.dart';

class WelcomeSection extends StatelessWidget {
  final AuthService? authService;

  const WelcomeSection({super.key, this.authService});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              Container(
                width: 190,
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.phone_android,
                        size: 80,
                        color: AppColors.offline,
                      ),
                    ),
                    Positioned(
                      top: 30,
                      left: 40,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 60,
                      right: 50,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.greenDark,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 50,
                      left: 30,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                authService?.currentUser != null
                    ? 'Hi ${authService?.currentUserName?.toUpperCase() ?? authService!.currentUser!.split('@')[0].toUpperCase()}'
                    : 'Hi USER',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getGreeting(),
                style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 230),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppColors.cardShadow,
                ),
                child: const Text(
                  'आA',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
