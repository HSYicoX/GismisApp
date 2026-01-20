import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// A calm, styled error view with retry option.
/// Displays error messages in a friendly, non-alarming way.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.title,
    this.message,
    this.icon,
    this.onRetry,
    this.retryLabel,
  });

  /// Creates an error view for network errors.
  factory ErrorView.network({VoidCallback? onRetry, Key? key}) {
    return ErrorView(
      key: key,
      title: '网络连接失败',
      message: '请检查网络连接后重试',
      icon: Icons.wifi_off_rounded,
      onRetry: onRetry,
    );
  }

  /// Creates an error view for server errors.
  factory ErrorView.server({VoidCallback? onRetry, Key? key}) {
    return ErrorView(
      key: key,
      title: '服务暂时不可用',
      message: '请稍后再试',
      icon: Icons.cloud_off_rounded,
      onRetry: onRetry,
    );
  }

  /// Creates an error view for not found errors.
  factory ErrorView.notFound({String? message, Key? key}) {
    return ErrorView(
      key: key,
      title: '内容未找到',
      message: message ?? '您访问的内容可能已被移除',
      icon: Icons.search_off_rounded,
    );
  }

  final String? title;
  final String? message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    // Truncate very long messages to prevent overflow
    final displayMessage = message != null && message!.length > 100
        ? '${message!.substring(0, 100)}...'
        : message;

    return Center(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.error_outline_rounded,
                size: 40,
                color: AppColors.error,
              ),
            ),
            AppSpacing.verticalLg,

            // Title
            if (title != null)
              Text(
                title!,
                style: AppTypography.headlineSmall,
                textAlign: TextAlign.center,
              ),

            if (title != null && displayMessage != null) AppSpacing.verticalSm,

            // Message (truncated to prevent overflow)
            if (displayMessage != null)
              Text(
                displayMessage,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

            // Retry button
            if (onRetry != null) ...[
              AppSpacing.verticalLg,
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(retryLabel ?? '重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact inline error widget for smaller spaces.
class InlineError extends StatelessWidget {
  const InlineError({required this.message, super.key, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: AppColors.error,
          ),
          AppSpacing.horizontalSm,
          Flexible(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
          if (onRetry != null) ...[
            AppSpacing.horizontalSm,
            GestureDetector(
              onTap: onRetry,
              child: const Icon(
                Icons.refresh_rounded,
                size: 16,
                color: AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
