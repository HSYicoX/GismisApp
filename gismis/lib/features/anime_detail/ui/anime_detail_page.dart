import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../shared/models/anime_detail.dart';
import '../../../shared/models/anime_platform.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../domain/anime_detail_providers.dart';

/// Anime detail page displaying comprehensive information about an anime.
/// Shows offline banner when network is unavailable.
class AnimeDetailPage extends ConsumerStatefulWidget {
  const AnimeDetailPage({required this.animeId, super.key});

  final String animeId;

  @override
  ConsumerState<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends ConsumerState<AnimeDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(animeDetailProvider(widget.animeId));
    final followState = ref.watch(followStatusProvider(widget.animeId));
    final isOffline = ref.watch(isOfflineProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Offline banner at the top
          if (isOffline) const OfflineBanner(),
          Expanded(
            child: detailState.isLoading && detailState.detail == null
                ? const _LoadingSkeleton()
                : detailState.error != null && detailState.detail == null
                ? ErrorView(
                    title: '加载失败',
                    message: detailState.error,
                    onRetry: () => ref
                        .read(animeDetailProvider(widget.animeId).notifier)
                        .refresh(),
                  )
                : _buildContent(detailState, followState),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AnimeDetailState detailState, FollowState followState) {
    final detail = detailState.detail;
    if (detail == null) return const SizedBox.shrink();

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        _buildSliverAppBar(detail, followState),
        SliverToBoxAdapter(child: _buildTabBar()),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(detail: detail),
          _TrackingTab(animeId: widget.animeId, detail: detail),
          _InsightsTab(detail: detail),
          _AiTab(animeId: widget.animeId),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(AnimeDetail detail, FollowState followState) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'anime_cover_${detail.id}',
              child: CachedNetworkImage(
                imageUrl: detail.coverUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: AppColors.skeleton),
                errorWidget: (context, url, error) => ColoredBox(
                  color: AppColors.skeleton,
                  child: const Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.background.withValues(alpha: 0.8),
                    AppColors.background,
                  ],
                  stops: const [0.3, 0.7, 1.0],
                ),
              ),
            ),
            // Title and buttons
            Positioned(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
              bottom: AppSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    detail.title,
                    style: AppTypography.headlineLarge.copyWith(
                      fontFamily: AppTypography.titleFontFamily,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppSpacing.verticalSm,
                  _buildActionButtons(followState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(FollowState followState) {
    final notifier = ref.read(followStatusProvider(widget.animeId).notifier);

    return Row(
      children: [
        // Follow button
        _ActionButton(
          icon: followState.isFollowed ? Icons.bookmark : Icons.bookmark_border,
          label: followState.isFollowed ? '已追番' : '追番',
          isActive: followState.isFollowed,
          isLoading: followState.isLoading,
          onTap: notifier.toggleFollow,
        ),
        AppSpacing.horizontalSm,
        // Favorite button (only show if followed)
        if (followState.isFollowed)
          _ActionButton(
            icon: followState.isFavorite
                ? Icons.favorite
                : Icons.favorite_border,
            label: followState.isFavorite ? '已收藏' : '收藏',
            isActive: followState.isFavorite,
            isLoading: followState.isLoading,
            onTap: notifier.toggleFavorite,
          ),
      ],
    );
  }

  Widget _buildTabBar() {
    return ColoredBox(
      color: AppColors.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textTertiary,
        indicatorColor: AppColors.accentOlive,
        labelStyle: AppTypography.labelLarge,
        tabs: const [
          Tab(text: '概览'),
          Tab(text: '追番'),
          Tab(text: '资料'),
          Tab(text: 'AI'),
        ],
      ),
    );
  }
}

/// Action button for follow/favorite.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accentOlive.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isActive ? AppColors.accentOlive : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? AppColors.accentOlive
                    : AppColors.textSecondary,
              ),
            AppSpacing.horizontalXs,
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isActive
                    ? AppColors.accentOlive
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Overview tab showing description and platforms.
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.detail});

  final AnimeDetail detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        // Summary
        if (detail.summary != null && detail.summary!.isNotEmpty) ...[
          Text('简介', style: AppTypography.titleMedium),
          AppSpacing.verticalSm,
          Text(detail.summary!, style: AppTypography.bodyMedium),
          AppSpacing.verticalLg,
        ],
        // Platforms
        if (detail.platforms.isNotEmpty) ...[
          Text('播放平台', style: AppTypography.titleMedium),
          AppSpacing.verticalSm,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: detail.platforms
                .map((p) => _PlatformChip(platform: p))
                .toList(),
          ),
          AppSpacing.verticalLg,
        ],
        // Episode info
        if (detail.episodeState != null) ...[
          Text('更新状态', style: AppTypography.titleMedium),
          AppSpacing.verticalSm,
          _buildEpisodeInfo(),
        ],
      ],
    );
  }

  Widget _buildEpisodeInfo() {
    final state = detail.episodeState!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('最新集数', style: AppTypography.labelSmall),
                Text(
                  '第${state.latestEpisode}集',
                  style: AppTypography.titleMedium,
                ),
              ],
            ),
          ),
          if (state.latestTitle != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('最新标题', style: AppTypography.labelSmall),
                  Text(
                    state.latestTitle!,
                    style: AppTypography.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Platform chip with external link.
class _PlatformChip extends StatelessWidget {
  const _PlatformChip({required this.platform});

  final AnimePlatform platform;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _getPlatformInfo(platform.platform);

    return GestureDetector(
      onTap: () => _launchUrl(platform.url),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(color: color),
            ),
            AppSpacing.horizontalXs,
            Icon(Icons.open_in_new, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  (String, Color) _getPlatformInfo(String platform) {
    return switch (platform.toLowerCase()) {
      'bilibili' => ('B站', AppColors.accentSky),
      'tencent' || 'qq' => ('腾讯视频', AppColors.accentOlive),
      'iqiyi' => ('爱奇艺', AppColors.accentTerracotta),
      'youku' => ('优酷', AppColors.accentLavender),
      'mgtv' => ('芒果TV', AppColors.accentTerracotta),
      _ => (platform, AppColors.textSecondary),
    };
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Tracking tab for progress management.
class _TrackingTab extends ConsumerWidget {
  const _TrackingTab({required this.animeId, required this.detail});

  final String animeId;
  final AnimeDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followState = ref.watch(followStatusProvider(animeId));

    if (!followState.isFollowed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 48,
              color: AppColors.textTertiary,
            ),
            AppSpacing.verticalMd,
            Text('追番后可记录观看进度', style: AppTypography.bodyMedium),
          ],
        ),
      );
    }

    final follow = followState.follow!;
    // Use latestEpisode as the total since totalEpisodes is not available
    final totalEpisodes = detail.episodeState?.latestEpisode ?? 12;

    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        Text('观看进度', style: AppTypography.titleMedium),
        AppSpacing.verticalMd,
        _ProgressCard(
          currentEpisode: follow.progressEpisode,
          totalEpisodes: totalEpisodes,
          onIncrement: () {
            if (follow.progressEpisode < totalEpisodes) {
              ref
                  .read(followStatusProvider(animeId).notifier)
                  .updateProgress(follow.progressEpisode + 1);
            }
          },
          onDecrement: () {
            if (follow.progressEpisode > 0) {
              ref
                  .read(followStatusProvider(animeId).notifier)
                  .updateProgress(follow.progressEpisode - 1);
            }
          },
        ),
        AppSpacing.verticalLg,
        // Notes section placeholder
        Text('备注', style: AppTypography.titleMedium),
        AppSpacing.verticalSm,
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text(
            follow.notes ?? '暂无备注',
            style: AppTypography.bodyMedium.copyWith(
              color: follow.notes != null
                  ? AppColors.textPrimary
                  : AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Progress card with increment/decrement buttons.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.currentEpisode,
    required this.totalEpisodes,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int currentEpisode;
  final int totalEpisodes;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final progress = totalEpisodes > 0 ? currentEpisode / totalEpisodes : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: currentEpisode > 0 ? onDecrement : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.accentOlive,
              ),
              Column(
                children: [
                  Text(
                    '$currentEpisode / $totalEpisodes',
                    style: AppTypography.headlineMedium,
                  ),
                  Text('已观看集数', style: AppTypography.labelSmall),
                ],
              ),
              IconButton(
                onPressed: currentEpisode < totalEpisodes ? onIncrement : null,
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.accentOlive,
              ),
            ],
          ),
          AppSpacing.verticalMd,
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.divider,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentOlive),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Insights tab showing source material and AI summaries.
class _InsightsTab extends StatelessWidget {
  const _InsightsTab({required this.detail});

  final AnimeDetail detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        // Source material info
        if (detail.sourceType != null || detail.sourceTitle != null) ...[
          Text('原作信息', style: AppTypography.titleMedium),
          AppSpacing.verticalSm,
          _buildSourceInfo(),
          AppSpacing.verticalLg,
        ],
        // AI digest
        if (detail.aiDigest != null) ...[
          Text('AI 摘要', style: AppTypography.titleMedium),
          AppSpacing.verticalSm,
          _buildAiDigest(),
        ],
        // Empty state
        if (detail.sourceType == null &&
            detail.sourceTitle == null &&
            detail.aiDigest == null)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppSpacing.verticalXxl,
                Icon(
                  Icons.info_outline,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
                AppSpacing.verticalMd,
                Text('暂无资料信息', style: AppTypography.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSourceInfo() {
    final sourceTypeLabel = switch (detail.sourceType?.toLowerCase()) {
      'manga' => '漫画',
      'novel' || 'light_novel' => '轻小说',
      'game' => '游戏',
      'original' => '原创',
      _ => detail.sourceType ?? '未知',
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_stories,
                size: 20,
                color: AppColors.accentLavender,
              ),
              AppSpacing.horizontalSm,
              Text('类型: $sourceTypeLabel', style: AppTypography.bodyMedium),
            ],
          ),
          if (detail.sourceTitle != null) ...[
            AppSpacing.verticalSm,
            Text(
              '原作: ${detail.sourceTitle}',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiDigest() {
    final digest = detail.aiDigest!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentSky.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.accentSky.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: AppColors.accentSky),
              AppSpacing.horizontalSm,
              Text(
                'AI 生成',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.accentSky,
                ),
              ),
            ],
          ),
          if (digest.summary != null) ...[
            AppSpacing.verticalMd,
            Text(digest.summary!, style: AppTypography.bodyMedium),
          ],
          if (digest.keyPoints != null && digest.keyPoints!.isNotEmpty) ...[
            AppSpacing.verticalMd,
            Text('要点:', style: AppTypography.labelMedium),
            AppSpacing.verticalSm,
            ...digest.keyPoints!.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: AppTypography.bodyMedium),
                    Expanded(
                      child: Text(point, style: AppTypography.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// AI assistant tab placeholder.
class _AiTab extends ConsumerWidget {
  const _AiTab({required this.animeId});

  final String animeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiDigestAsync = ref.watch(aiDigestProvider(animeId));

    return aiDigestAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            AppSpacing.verticalMd,
            Text('加载失败', style: AppTypography.bodyMedium),
          ],
        ),
      ),
      data: (digest) => ListView(
        padding: AppSpacing.pagePadding,
        children: [
          // AI assistant header
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentSky.withValues(alpha: 0.15),
                  AppColors.accentLavender.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(
                    Icons.smart_toy,
                    color: AppColors.accentSky,
                  ),
                ),
                AppSpacing.horizontalMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI 助手', style: AppTypography.titleMedium),
                      Text('为你解答关于这部番剧的问题', style: AppTypography.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.verticalLg,
          // Quick questions
          Text('快速提问', style: AppTypography.titleMedium),
          AppSpacing.verticalSm,
          _QuickQuestionChip(label: '这部番讲了什么?'),
          AppSpacing.verticalXs,
          _QuickQuestionChip(label: '有哪些主要角色?'),
          AppSpacing.verticalXs,
          _QuickQuestionChip(label: '适合什么人群观看?'),
          AppSpacing.verticalLg,
          // Coming soon notice
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Icon(Icons.construction, color: AppColors.textTertiary),
                AppSpacing.horizontalMd,
                Expanded(
                  child: Text(
                    'AI 对话功能即将上线',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick question chip.
class _QuickQuestionChip extends StatelessWidget {
  const _QuickQuestionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: Implement AI chat
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.bodyMedium)),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading skeleton for the detail page.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover skeleton
          const SkeletonLoader(height: 300, width: double.infinity),
          Padding(
            padding: AppSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title skeleton
                const SkeletonLoader(height: 28, width: 200),
                AppSpacing.verticalMd,
                // Buttons skeleton
                Row(
                  children: [
                    SkeletonLoader(
                      height: 36,
                      width: 80,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    AppSpacing.horizontalSm,
                    SkeletonLoader(
                      height: 36,
                      width: 80,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ],
                ),
                AppSpacing.verticalLg,
                // Tab bar skeleton
                const SkeletonLoader(height: 48, width: double.infinity),
                AppSpacing.verticalLg,
                // Content skeleton
                const SkeletonLoader(height: 16, width: double.infinity),
                AppSpacing.verticalSm,
                const SkeletonLoader(height: 16, width: double.infinity),
                AppSpacing.verticalSm,
                const SkeletonLoader(height: 16, width: 200),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
