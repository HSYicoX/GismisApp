import 'package:flutter/material.dart';

import '../../app/theme/app_animations.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// An offline indicator banner that shows when network is unavailable.
/// Displays at the top of the screen with a calm, non-intrusive style.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.message,
    this.onRetry,
  });

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.textSecondary,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 16,
              color: AppColors.surface,
            ),
            AppSpacing.horizontalSm,
            Flexible(
              child: Text(
                message ?? '当前处于离线模式',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.surface,
                ),
              ),
            ),
            if (onRetry != null) ...[
              AppSpacing.horizontalMd,
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    '重试',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.surface,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// An animated offline banner that slides in/out based on connectivity.
class AnimatedOfflineBanner extends StatelessWidget {
  const AnimatedOfflineBanner({
    required this.isOffline,
    super.key,
    this.message,
    this.onRetry,
  });

  final bool isOffline;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: AppAnimations.medium,
      curve: AppAnimations.defaultCurve,
      offset: isOffline ? Offset.zero : const Offset(0, -1),
      child: AnimatedOpacity(
        duration: AppAnimations.medium,
        opacity: isOffline ? 1 : 0,
        child: OfflineBanner(
          message: message,
          onRetry: onRetry,
        ),
      ),
    );
  }
}

/// A wrapper widget that shows offline banner above its child.
class OfflineAwareScaffold extends StatelessWidget {
  const OfflineAwareScaffold({
    required this.isOffline,
    required this.child,
    super.key,
    this.message,
    this.onRetry,
  });

  final bool isOffline;
  final Widget child;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedOfflineBanner(
          isOffline: isOffline,
          message: message,
          onRetry: onRetry,
        ),
        Expanded(child: child),
      ],
    );
  }
}
