import 'package:flutter/material.dart';
import 'package:taxiapp/core/app_colors.dart';

/// Swipe or tap to confirm (e.g. ARRIVED, DROP REACHED).
class SlideToConfirm extends StatefulWidget {
  final String label;
  final VoidCallback? onConfirmed;
  final bool enabled;

  const SlideToConfirm({
    super.key,
    required this.label,
    this.onConfirmed,
    this.enabled = true,
  });

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  double _drag = 0;
  bool _confirmed = false;

  @override
  void didUpdateWidget(SlideToConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled && widget.enabled) {
      _drag = 0;
      _confirmed = false;
    }
  }

  void _complete() {
    if (!widget.enabled || _confirmed) return;
    setState(() => _confirmed = true);
    widget.onConfirmed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = (constraints.maxWidth - 56).clamp(0.0, double.infinity);
        final progress = maxDrag > 0 ? (_drag / maxDrag).clamp(0.0, 1.0) : 0.0;

        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: widget.enabled ? AppColors.cardDarkElevated : AppColors.cardDark,
            borderRadius: AppColors.radiusMd,
            border: Border.all(
              color: widget.enabled ? AppColors.green : AppColors.textMuted,
              width: widget.enabled ? 2 : 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                child: Center(
                  child: Text(
                    widget.enabled
                        ? '${widget.label}  ·  tap or swipe →'
                        : widget.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.enabled ? AppColors.textPrimary : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: _drag,
                child: GestureDetector(
                  onTap: widget.enabled && !_confirmed ? _complete : null,
                  onHorizontalDragUpdate: widget.enabled && !_confirmed
                      ? (d) => setState(() => _drag = (_drag + d.delta.dx).clamp(0, maxDrag))
                      : null,
                  onHorizontalDragEnd: widget.enabled && !_confirmed
                      ? (_) {
                          if (progress >= 0.75) {
                            setState(() => _drag = maxDrag);
                            _complete();
                          } else {
                            setState(() => _drag = 0);
                          }
                        }
                      : null,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: widget.enabled ? AppColors.greenGradient : null,
                      color: widget.enabled ? null : AppColors.textMuted,
                      borderRadius: AppColors.radiusMd,
                    ),
                    child: Icon(
                      _confirmed ? Icons.check : Icons.chevron_right,
                      color: AppColors.cardDark,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
