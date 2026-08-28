import 'package:flutter/material.dart';
import 'package:taxiapp/authentication_page/auth_service.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/taxi_icons.dart';

class PerformanceCard extends StatelessWidget {
  const PerformanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService(),
      builder: (context, _) {
        final authData = AuthService();
        final accepted = authData.acceptedOrders;
        final total = authData.totalOrders;
        final rate = authData.acceptanceRate.toStringAsFixed(1);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: AppColors.greenGradient,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Rate $rate%',
                      style: const TextStyle(
                        color: AppColors.textOnDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$accepted/$total Accepted Orders',
                    style: const TextStyle(
                      color: AppColors.textOnDark,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.textOnDark,
                    ),
                    child: const Text(
                      'Know more →',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: const Icon(
                        TaxiIcons.profile,
                        size: 50,
                        color: AppColors.textOnDark,
                      ),
                    ),
                    const Positioned(
                      top: -5,
                      right: 20,
                      child: Icon(TaxiIcons.star, color: AppColors.textOnDark, size: 16),
                    ),
                    const Positioned(
                      bottom: -5,
                      right: 20,
                      child: Icon(TaxiIcons.star, color: AppColors.textOnDark, size: 16),
                    ),
                    const Positioned(
                      top: 20,
                      right: -5,
                      child: Icon(TaxiIcons.star, color: AppColors.textOnDark, size: 16),
                    ),
                    const Positioned(
                      top: 20,
                      left: -5,
                      child: Icon(TaxiIcons.star, color: AppColors.textOnDark, size: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
