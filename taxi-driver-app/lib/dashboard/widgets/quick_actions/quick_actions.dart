import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/taxi_icons.dart';

class QuickActions extends StatelessWidget {
  final VoidCallback onOrdersTap;

  const QuickActions({super.key, required this.onOrdersTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/incentives'),
            child: _buildQuickActionIcon(
              icon: TaxiIcons.star,
              label: 'Incentives',
              color: AppColors.green,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/earnings'),
            child: _buildQuickActionIcon(
              icon: TaxiIcons.earnings,
              label: 'Earnings',
              color: AppColors.black,
            ),
          ),
          GestureDetector(
            onTap: onOrdersTap,
            child: _buildQuickActionIcon(
              icon: TaxiIcons.ride,
              label: 'Orders',
              color: AppColors.greenDark,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/more-settings'),
            child: _buildQuickActionIcon(
              icon: TaxiIcons.menu,
              label: 'More',
              color: AppColors.blackLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionIcon({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: AppColors.textOnDark, size: 24),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
