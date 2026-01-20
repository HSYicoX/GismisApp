import 'package:flutter/material.dart';

import '../../app/theme/app_animations.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// A skeleton loader widget with shimmer animation for loading states.
/// Provides artistic, styled placeholders while content is being fetched.
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    required this.width,
    required this.height,
    super.key,
    this.borderRadius,
  });

  /// Creates a circular skeleton loader.
  const SkeletonLoader.circle({
    required double size,
    super.key,
  })  : width = size,
        height = size,
        borderRadius = null;

  /// Creates a text-line skeleton loader.
  factory SkeletonLoader.text({
    double width = double.infinity,
    double height = 16,
    Key? key,
  }) {
    return SkeletonLoader(
      key: key,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm / 2),
    );
  }

  /// Creates a card skeleton loader.
  factory SkeletonLoader.card({
    double width = double.infinity,
    double height = 120,
    Key? key,
  }) {
    return SkeletonLoader(
      key: key,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    );
  }

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.shimmer,
    )..repeat();

    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCircle = widget.borderRadius == null &&
        widget.width == widget.height;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: isCircle
                ? BorderRadius.circular(widget.width / 2)
                : widget.borderRadius ?? BorderRadius.circular(AppSpacing.radiusSm),
            gradient: LinearGradient(
              colors: const [
                AppColors.skeleton,
                AppColors.shimmerHighlight,
                AppColors.skeleton,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
            ),
          ),
          child: SizedBox(
            width: widget.width,
            height: widget.height,
          ),
        );
      },
    );
  }
}

/// A skeleton loader for anime cards.
class AnimeCardSkeleton extends StatelessWidget {
  const AnimeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image skeleton
          SkeletonLoader.card(height: 180),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title skeleton
                SkeletonLoader.text(width: 120, height: 18),
                AppSpacing.verticalXs,
                // Subtitle skeleton
                SkeletonLoader.text(width: 80, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A skeleton loader for list items.
class ListItemSkeleton extends StatelessWidget {
  const ListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Avatar/thumbnail skeleton
          const SkeletonLoader.circle(size: 48),
          AppSpacing.horizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader.text(width: 160),
                AppSpacing.verticalXs,
                SkeletonLoader.text(width: 100, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
