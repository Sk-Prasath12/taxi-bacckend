import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/taxi_icons.dart';

enum FigmaNavTab { drive, earnings, profile }

class FigmaBottomNav extends StatelessWidget {
  final FigmaNavTab current;
  final ValueChanged<FigmaNavTab> onChanged;

  const FigmaBottomNav({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
      decoration: BoxDecoration(
        color: AppColors.scaffoldDark,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.map_rounded,
            label: 'Drive',
            selected: current == FigmaNavTab.drive,
            selectedColor: AppColors.green,
            onTap: () => onChanged(FigmaNavTab.drive),
          ),
          _NavItem(
            icon: TaxiIcons.earnings,
            label: 'Earnings',
            selected: current == FigmaNavTab.earnings,
            selectedColor: AppColors.gold,
            onTap: () => onChanged(FigmaNavTab.earnings),
          ),
          _NavItem(
            icon: TaxiIcons.profile,
            label: 'Profile',
            selected: current == FigmaNavTab.profile,
            selectedColor: AppColors.textSecondary,
            onTap: () => onChanged(FigmaNavTab.profile),
          ),
        ],
      ),
    ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(color: selectedColor, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
