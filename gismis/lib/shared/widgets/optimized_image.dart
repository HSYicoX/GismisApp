import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme/app_animations.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// An optimized image widget with lazy loading and progressive quality.
///
/// Features:
/// - Lazy loading with fade-in animation
/// - Placeholder with skeleton style
/// - Error handling with fallback icon
/// - Memory cache optimization
/// - Maintain 60 FPS during list scrolling
///
/// Requirements: 11.4.1, 11
class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Color? placeholderColor;
  final IconData? errorIcon;
  final Duration? fadeInDuration;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderColor,
    this.errorIcon,
    this.fadeInDuration,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = width != null
        ? (width! * devicePixelRatio).toInt().clamp(100, 400)
        : 300;

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth ?? cacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: fadeInDuration ?? AppAnimations.fast,
      fadeOutDuration: const Duration(milliseconds: 100),
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildError(),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: placeholderColor ?? AppColors.skeleton,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.textTertiary,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: width,
      height: height,
      color: placeholderColor ?? AppColors.skeleton,
      child: Center(
        child: Icon(
          errorIcon ?? Icons.broken_image_outlined,
          color: AppColors.textTertiary,
          size: 24,
        ),
      ),
    );
  }
}

/// A cover image optimized for anime cards.
class OptimizedCoverImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final String? heroTag;

  const OptimizedCoverImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = width != null
        ? (width! * devicePixelRatio).toInt().clamp(100, 400)
        : 300;

    Widget image = OptimizedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      memCacheWidth: cacheWidth,
      memCacheHeight: (cacheWidth * 4 / 3).toInt(),
      borderRadius: borderRadius ?? BorderRadius.circular(AppSpacing.radiusSm),
    );

    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }

    return image;
  }
}

/// A thumbnail image optimized for list items.
class OptimizedThumbnail extends StatelessWidget {
  final String imageUrl;
  final double size;
  final BorderRadius? borderRadius;
  final String? heroTag;

  const OptimizedThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 56,
    this.borderRadius,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (size * devicePixelRatio).toInt().clamp(50, 150);

    Widget image = OptimizedImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      memCacheWidth: cacheSize,
      memCacheHeight: cacheSize,
      borderRadius: borderRadius ?? BorderRadius.circular(AppSpacing.radiusSm),
    );

    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }

    return image;
  }
}
