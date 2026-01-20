import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/models/schedule_entry.dart';

/// A tile widget for displaying an anime entry in the weekly schedule.
///
/// Features:
/// - Anime cover image with Hero animation
/// - Title and latest episode info
/// - User progress indicator
/// - Progress increment button
/// - Long-press support for reorder mode
/// - Visual distinction for followed anime
class ScheduleEntryTile extends StatelessWidget {
  const ScheduleEntryTile({
    required this.entry,
    super.key,
    this.onTap,
    this.onLongPress,
    this.onIncrementProgress,
    this.isReorderMode = false,
    this.heroTag,
  });

  /// The schedule entry data to display.
  final ScheduleEntry entry;

  /// Callback when the tile is tapped.
  final VoidCallback? onTap;

  /// Callback when the tile is long-pressed.
  final VoidCallback? onLongPress;

  /// Callback when the progress increment button is pressed.
  final VoidCallback? onIncrementProgress;

  /// Whether the tile is in reorder mode.
  final bool isReorderMode;

  /// Custom hero tag for the cover image animation.
  final String? heroTag;

  bool get _isFollowed => entry.userFollow != null;
  int get _userProgress => entry.userFollow?.progressEpisode ?? 0;
  bool get _isUpToDate => _userProgress >= entry.latestEpisode;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.sm / 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: _isFollowed
                ? AppColors.accentOlive.withValues(alpha: 0.3)
                : AppColors.divider,
            width: _isFollowed ? 1.5 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              // Reorder handle (shown in reorder mode)
              if (isReorderMode) _buildReorderHandle(),
              // Cover image
              _buildCoverImage(),
              AppSpacing.horizontalMd,
              // Content
              Expanded(child: _buildContent()),
              // Progress section
              _buildProgressSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReorderHandle() {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Icon(Icons.drag_handle, color: AppColors.textTertiary, size: 20),
    );
  }

  Widget _buildCoverImage() {
    final tag = heroTag ?? 'schedule_cover_${entry.anime.id}';

    return Hero(
      tag: tag,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: CachedNetworkImage(
          imageUrl: entry.anime.coverUrl,
          width: 56,
          height: 75,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              Container(width: 56, height: 75, color: AppColors.skeleton),
          errorWidget: (context, url, error) => Container(
            width: 56,
            height: 75,
            color: AppColors.skeleton,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          entry.anime.title,
          style: AppTypography.titleSmall.copyWith(
            fontFamily: AppTypography.titleFontFamily,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        AppSpacing.verticalXs,
        // Latest episode info
        Row(
          children: [
            _buildLatestEpisodeBadge(),
            if (_isFollowed) ...[
              AppSpacing.horizontalSm,
              _buildFollowedBadge(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildLatestEpisodeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentSky.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        '更新至第${entry.latestEpisode}集',
        style: AppTypography.labelSmall.copyWith(color: AppColors.accentSky),
      ),
    );
  }

  Widget _buildFollowedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentOlive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark, size: 10, color: AppColors.accentOlive),
          const SizedBox(width: 2),
          Text(
            '已追',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.accentOlive,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    if (!_isFollowed) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress indicator
        _buildProgressIndicator(),
        AppSpacing.verticalXs,
        // Increment button
        _buildIncrementButton(),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    final progressText = '$_userProgress/${entry.latestEpisode}';
    final progressColor = _isUpToDate
        ? AppColors.success
        : AppColors.accentTerracotta;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: progressColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        progressText,
        style: AppTypography.labelMedium.copyWith(
          color: progressColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildIncrementButton() {
    if (_isUpToDate) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 12, color: AppColors.success),
            const SizedBox(width: 2),
            Text(
              '已追完',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onIncrementProgress,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.accentOlive.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(
              color: AppColors.accentOlive.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 14, color: AppColors.accentOlive),
              const SizedBox(width: 2),
              Text(
                '+1',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.accentOlive,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A skeleton loader for schedule entry tiles.
class ScheduleEntryTileSkeleton extends StatelessWidget {
  const ScheduleEntryTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.sm / 2,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          // Cover skeleton
          Container(
            width: 56,
            height: 75,
            decoration: BoxDecoration(
              color: AppColors.skeleton,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
          AppSpacing.horizontalMd,
          // Content skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.skeleton,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                AppSpacing.verticalSm,
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.skeleton,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.horizontalMd,
          // Progress skeleton
          Container(
            width: 50,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.skeleton,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
        ],
      ),
    );
  }
}
