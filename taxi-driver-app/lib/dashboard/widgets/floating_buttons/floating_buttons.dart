import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:taxiapp/core/app_colors.dart';
import 'dart:ui' as ui;

class FloatingOrdersButtons extends StatelessWidget {
  final Animation<double> animation;
  final VoidCallback onOnProgressTap;
  final VoidCallback onCompletedTap;

  const FloatingOrdersButtons({
    super.key,
    required this.animation,
    required this.onOnProgressTap,
    required this.onCompletedTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        const double startTop = 195;
        const double startLeft = 25;

        const double anchorWidth = 70;
        const double anchorHeight = 90;
        const double gap = 15;

        final double targetLeft1 = startLeft + anchorWidth + gap - 8;
        final double targetTop1 = startTop + anchorHeight + gap - 65;

        final double targetLeft2 = startLeft;
        final double targetTop2 = startTop + anchorHeight + gap - 8;

        const double itemSize = 55;
        final double originLeft = startLeft + (anchorWidth - itemSize) / 2;
        final double originTop = startTop + (anchorHeight - itemSize) / 2;

        final double val = Curves.easeInOut.transform(
          animation.value.clamp(0.0, 1.0),
        );
        if (val == 0) return const SizedBox.shrink();

        final double currentLeft1 = ui.lerpDouble(
          originLeft,
          targetLeft1,
          val,
        )!;
        final double currentTop1 = ui.lerpDouble(originTop, targetTop1, val)!;

        final double currentLeft2 = ui.lerpDouble(
          originLeft,
          targetLeft2,
          val,
        )!;
        final double currentTop2 = ui.lerpDouble(originTop, targetTop2, val)!;

        return Stack(
          children: [
            Positioned(
              top: currentTop1,
              left: currentLeft1,
              child: Opacity(
                opacity: val.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: val,
                  child: GestureDetector(
                    onTap: onOnProgressTap,
                    child: _floatingItem(
                      'On Progress',
                      'assets/dashboard/on progress.svg',
                      AppColors.blackLight,
                      val > 0.99,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: currentTop2,
              left: currentLeft2,
              child: Opacity(
                opacity: val.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: val,
                  child: GestureDetector(
                    onTap: onCompletedTap,
                    child: _floatingItem(
                      'Completed',
                      'assets/dashboard/completed.svg',
                      AppColors.greenLight,
                      val > 0.99,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _floatingItem(String label, String asset, Color bg, bool showLabel) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 55,
          height: 55,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: AppColors.cardShadow,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: SvgPicture.asset(asset),
        ),
        const SizedBox(height: 6),
        if (showLabel)
          Material(
            color: Colors.transparent,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
      ],
    );
  }
}
