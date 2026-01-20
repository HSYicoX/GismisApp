import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../models/anime.dart';
import 'optimized_image.dart';

/// A card widget displaying anime information with artistic styling.
///
/// Features:
/// - Cover image with Hero animation for detail page transition
/// - Title with serif font
/// - Platform badges
/// - Latest episode indicator
/// - Subtle shadows and rounded corners
class AnimeCard extends StatelessWidget {
  const AnimeCard({
    required this.anime,
    super.key,
    this.onTap,
    this.onLongPress,
    this.platforms = const [],
    this.latestEpisode,
    this.showStatus = true,
    this.heroTag,
  });

  /// The anime data to display.
  final Anime anime;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Callback when the card is long-pressed.
  final VoidCallback? onLongPress;

  /// List of platform names to display as badges.
  final List<String> platforms;

  /// Latest episode number to display.
  final int? latestEpisode;

  /// Whether to show the anime status badge.
  final bool showStatus;

  /// Custom hero tag for the cover image animation.
  /// Defaults to 'anime_cover_{anime.id}'.
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image with Hero animation
            Expanded(child: _buildCoverImage()),
            // Content section
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  _buildTitle(),
                  AppSpacing.verticalXs,
                  // Platform badges and episode info
                  _buildMetaRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    final tag = heroTag ?? 'anime_cover_${anime.id}';

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover image with Hero and optimized loading
          OptimizedCoverImage(imageUrl: anime.coverUrl, heroTag: tag),
          // Status badge overlay
          if (showStatus)
            Positioned(
              top: AppSpacing.xs,
              right: AppSpacing.xs,
              child: _buildStatusBadge(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final (label, color) = switch (anime.status) {
      AnimeStatus.ongoing => ('连载中', AppColors.accentOlive),
      AnimeStatus.completed => ('已完结', AppColors.accentSky),
      AnimeStatus.upcoming => ('即将开播', AppColors.accentTerracotta),
      AnimeStatus.hiatus => ('暂停更新', AppColors.textTertiary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      anime.title,
      style: AppTypography.titleSmall.copyWith(
        fontFamily: AppTypography.titleFontFamily,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMetaRow() {
    return Row(
      children: [
        // Platform badges
        if (platforms.isNotEmpty) ...[
          Expanded(
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: platforms.take(2).map(_buildPlatformBadge).toList(),
            ),
          ),
        ],
        // Latest episode
        if (latestEpisode != null) ...[const Spacer(), _buildEpisodeBadge()],
      ],
    );
  }

  Widget _buildPlatformBadge(String platform) {
    final (label, color) = _getPlatformInfo(platform);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm / 2),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(color: color, fontSize: 10),
      ),
    );
  }

  (String, Color) _getPlatformInfo(String platform) {
    return switch (platform.toLowerCase()) {
      'bilibili' => ('B站', AppColors.accentSky),
      'tencent' || 'qq' => ('腾讯', AppColors.accentOlive),
      'iqiyi' => ('爱奇艺', AppColors.accentTerracotta),
      'youku' => ('优酷', AppColors.accentLavender),
      'mgtv' => ('芒果', AppColors.accentTerracotta),
      _ => (platform, AppColors.textSecondary),
    };
  }

  Widget _buildEpisodeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentOlive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        '第$latestEpisode集',
        style: AppTypography.labelSmall.copyWith(color: AppColors.accentOlive),
      ),
    );
  }
}

/// A horizontal anime card for list views.
class AnimeListTile extends StatelessWidget {
  const AnimeListTile({
    required this.anime,
    super.key,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.subtitle,
    this.heroTag,
  });

  final Anime anime;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final String? subtitle;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final tag = heroTag ?? 'anime_cover_${anime.id}';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            // Cover thumbnail with Hero and optimized loading
            OptimizedThumbnail(
              imageUrl: anime.coverUrl,
              heroTag: tag,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            AppSpacing.horizontalMd,
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime.title,
                    style: AppTypography.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    AppSpacing.verticalXs,
                    Text(
                      subtitle!,
                      style: AppTypography.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Trailing widget
            if (trailing != null) ...[AppSpacing.horizontalSm, trailing!],
          ],
        ),
      ),
    );
  }
}

/// A compact anime card for horizontal scrolling lists.
class AnimeCompactCard extends StatelessWidget {
  const AnimeCompactCard({
    required this.anime,
    super.key,
    this.onTap,
    this.width = 120,
    this.heroTag,
  });

  final Anime anime;
  final VoidCallback? onTap;
  final double width;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final tag = heroTag ?? 'anime_cover_${anime.id}';

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image with optimized loading
            OptimizedCoverImage(
              imageUrl: anime.coverUrl,
              width: width,
              height: width * 4 / 3,
              heroTag: tag,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            AppSpacing.verticalXs,
            // Title
            Text(
              anime.title,
              style: AppTypography.labelMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
