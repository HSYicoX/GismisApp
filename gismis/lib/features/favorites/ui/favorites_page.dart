import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../data/favorites_repository.dart';
import '../domain/favorites_providers.dart';

/// The favorites collection page displaying user's favorite anime.
///
/// Features:
/// - Grid/list view of favorite anime
/// - Drag-to-reorder functionality
/// - Empty state with guidance
/// - Navigation to anime detail on tap
/// - Smooth animations for removal
/// - Offline banner when network is unavailable
class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  bool _isReorderMode = false;

  void _toggleReorderMode() {
    setState(() => _isReorderMode = !_isReorderMode);
  }

  void _navigateToDetail(String animeId) {
    context.push('/anime/$animeId');
  }

  void _navigateToExplore() {
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoritesProvider);
    final isOffline = ref.watch(isOfflineProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(state),
      body: Column(
        children: [
          // Offline banner
          if (isOffline) const OfflineBanner(),
          Expanded(child: _buildBody(state)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(FavoritesState state) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back_ios_rounded),
        color: AppColors.textPrimary,
      ),
      title: Text(
        '我的收藏',
        style: AppTypography.headlineMedium.copyWith(
          fontFamily: AppTypography.titleFontFamily,
        ),
      ),
      actions: [
        // Only show reorder button if there are favorites
        if (state.favorites.length > 1)
          IconButton(
            onPressed: _toggleReorderMode,
            icon: Icon(
              _isReorderMode ? Icons.check : Icons.reorder,
              color: _isReorderMode
                  ? AppColors.accentOlive
                  : AppColors.textSecondary,
            ),
            tooltip: _isReorderMode ? '完成排序' : '自定义排序',
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 0.5, color: AppColors.divider),
      ),
    );
  }

  Widget _buildBody(FavoritesState state) {
    if (state.isLoading && state.favorites.isEmpty) {
      return _buildLoadingState();
    }

    if (state.error != null && state.favorites.isEmpty) {
      return _buildErrorState(state.error!);
    }

    if (state.isEmpty) {
      return _buildEmptyState();
    }

    return _buildFavoritesList(state);
  }

  Widget _buildLoadingState() {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => const _FavoriteCardSkeleton(),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: ErrorView(
        title: '加载失败',
        message: error,
        onRetry: () {
          ref.read(favoritesProvider.notifier).refresh();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: EmptyView.favorites(onExplore: _navigateToExplore));
  }

  Widget _buildFavoritesList(FavoritesState state) {
    if (_isReorderMode) {
      return _buildReorderableList(state);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(favoritesProvider.notifier).refresh();
      },
      color: AppColors.accentOlive,
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
        ),
        itemCount: state.favorites.length,
        itemBuilder: (context, index) {
          final favorite = state.favorites[index];
          return _FavoriteCard(
            favorite: favorite,
            onTap: () => _navigateToDetail(favorite.anime.id),
            onRemove: () => _removeFavorite(favorite.anime.id),
            heroTag: 'favorite_${favorite.anime.id}',
          );
        },
      ),
    );
  }

  Widget _buildReorderableList(FavoritesState state) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: state.favorites.length,
      onReorder: (oldIndex, newIndex) {
        ref.read(favoritesProvider.notifier).reorder(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final elevation = Tween<double>(
              begin: 0,
              end: 8,
            ).evaluate(animation);
            return Material(
              elevation: elevation,
              color: Colors.transparent,
              shadowColor: AppColors.textPrimary.withValues(alpha: 0.2),
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final favorite = state.favorites[index];
        return _FavoriteListTile(
          key: ValueKey(favorite.anime.id),
          favorite: favorite,
          isReorderMode: true,
          heroTag: 'favorite_${favorite.anime.id}',
        );
      },
    );
  }

  void _removeFavorite(String animeId) {
    // Show confirmation dialog
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        title: Text('移除收藏', style: AppTypography.headlineSmall),
        content: Text('确定要将这部番剧从收藏中移除吗？', style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              '取消',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              '移除',
              style: AppTypography.labelLarge.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed ?? false) {
        ref.read(favoritesProvider.notifier).removeFromFavorites(animeId);
      }
    });
  }
}

/// A card widget for displaying a favorite anime in grid view.
class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.favorite,
    this.onTap,
    this.onRemove,
    this.heroTag,
  });

  final FavoriteAnime favorite;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final tag = heroTag ?? 'favorite_${favorite.anime.id}';

    return GestureDetector(
      onTap: onTap,
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
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image with Hero animation
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: tag,
                    child: CachedNetworkImage(
                      imageUrl: favorite.anime.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => ColoredBox(
                        color: AppColors.skeleton,
                        child: const Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: AppColors.textTertiary,
                            size: 32,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => ColoredBox(
                        color: AppColors.skeleton,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textTertiary,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Favorite badge
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.accentTerracotta.withValues(
                          alpha: 0.9,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                  // Remove button (on long press or swipe)
                  if (onRemove != null)
                    Positioned(
                      top: AppSpacing.xs,
                      left: AppSpacing.xs,
                      child: GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  // Progress indicator
                  if (favorite.follow.progressEpisode > 0)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppColors.textPrimary.withValues(alpha: 0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Text(
                          '看到第${favorite.follow.progressEpisode}集',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Title section
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                favorite.anime.title,
                style: AppTypography.titleSmall.copyWith(
                  fontFamily: AppTypography.titleFontFamily,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A list tile widget for displaying a favorite anime in reorder mode.
class _FavoriteListTile extends StatelessWidget {
  const _FavoriteListTile({
    required this.favorite,
    super.key,
    this.isReorderMode = false,
    this.heroTag,
  });

  final FavoriteAnime favorite;
  final bool isReorderMode;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final tag = heroTag ?? 'favorite_${favorite.anime.id}';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          // Drag handle
          if (isReorderMode)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Icon(Icons.drag_handle, color: AppColors.textTertiary),
            ),
          // Cover thumbnail with Hero
          Hero(
            tag: tag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: CachedNetworkImage(
                imageUrl: favorite.anime.coverUrl,
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
          ),
          AppSpacing.horizontalMd,
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  favorite.anime.title,
                  style: AppTypography.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.verticalXs,
                if (favorite.follow.progressEpisode > 0)
                  Text(
                    '看到第${favorite.follow.progressEpisode}集',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          // Favorite icon
          Icon(Icons.favorite, color: AppColors.accentTerracotta, size: 20),
        ],
      ),
    );
  }
}

/// Skeleton loader for favorite cards.
class _FavoriteCardSkeleton extends StatelessWidget {
  const _FavoriteCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover skeleton
          Expanded(child: SkeletonLoader.card(height: double.infinity)),
          // Title skeleton
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader.text(width: 100),
                AppSpacing.verticalXs,
                SkeletonLoader.text(width: 60, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
