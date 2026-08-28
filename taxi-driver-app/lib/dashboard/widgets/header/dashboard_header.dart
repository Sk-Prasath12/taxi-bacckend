import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/widgets/taxi_ui.dart';
import '../switch/custom_switch.dart';

class DashboardHeader extends StatelessWidget {
  final bool isOnDuty;
  final ValueChanged<bool> onDutyChanged;
  final VoidCallback onMenuPressed;
  final VoidCallback onHomePressed;
  final VoidCallback onNotificationsPressed;

  const DashboardHeader({
    super.key,
    required this.isOnDuty,
    required this.onDutyChanged,
    required this.onMenuPressed,
    required this.onHomePressed,
    required this.onNotificationsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: onMenuPressed,
          ),
          const Spacer(),
          TaxiStatusBadge(isOnline: isOnDuty),
          const SizedBox(width: 8),
          CustomAnimatedSwitch(value: isOnDuty, onChanged: onDutyChanged),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
            onPressed: onNotificationsPressed,
          ),
        ],
      ),
    );
  }
}
