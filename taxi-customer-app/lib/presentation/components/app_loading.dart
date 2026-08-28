import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Branded loading indicator — blue spinner + taxi icon.
class AppLoading extends StatelessWidget {
  final String? message;
  final double size;
  final bool fullScreen;

  const AppLoading({
    super.key,
    this.message,
    this.size = 48,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppTheme.primary,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                ),
              ),
              Icon(
                Icons.local_taxi_rounded,
                color: AppTheme.primary,
                size: size * 0.42,
              ),
            ],
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    if (fullScreen) {
      return Container(
        color: AppTheme.background,
        alignment: Alignment.center,
        child: content,
      );
    }
    return content;
  }
}

/// Full-screen overlay while login / bootstrap runs.
class AppLoadingOverlay extends StatelessWidget {
  final String message;

  const AppLoadingOverlay({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background.withValues(alpha: 0.92),
      alignment: Alignment.center,
      child: AppLoading(message: message, size: 56),
    );
  }
}
