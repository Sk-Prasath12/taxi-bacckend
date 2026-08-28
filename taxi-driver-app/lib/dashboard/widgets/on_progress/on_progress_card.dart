import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'package:taxiapp/core/taxi_icons.dart';

class OnProgressCard extends StatelessWidget {
  final VoidCallback? onTap;
  final String? destination;

  const OnProgressCard({super.key, this.onTap, this.destination});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
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
                  color: AppColors.green.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Current Ride',
                  style: TextStyle(
                    color: AppColors.textOnDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                destination != null
                    ? 'Heading to $destination'
                    : 'Heading to Destination',
                style: const TextStyle(
                  color: AppColors.textOnDark,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.green,
                ),
                child: const Text(
                  'View Details →',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.green.withValues(alpha: 0.25),
              ),
              child: const Icon(
                TaxiIcons.taxi,
                color: AppColors.textOnDark,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
