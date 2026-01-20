import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/anime_providers.dart';

/// Home page displaying the anime library with search and discovery features.
///
/// Features:
/// - Search bar at top
/// - "Today's Updates" horizontal section
/// - Main anime list with infinite scroll
/// - Loading, error, and empty states
/// - Offline banner when network is unavailable
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when near the bottom
      final query = ref.read(searchQueryProvider);
      if (query.isEmpty) {
        ref.read(animeListProvider.notifier).loadMore();
      } else {
        ref.read(searchResultsProvider(query).notifier).loadMore();
      }
    }
  }

  void _onSearchChanged(String value) {
    ref.read(searchQueryProvider.notifier).state = value;
  }

  void _onSearchClear() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  void _onAnimeTap(Anime anime) {
    context.push(AppRoutes.animeDetailPath(anime.id));
  }

  Future<void> _onRefresh() async {
    final query = ref.read(searchQueryProvider);
    if (query.isEmpty) {
      await ref.read(animeListProvider.notifier).refresh();
    } else {
      await ref.read(searchResultsProvider(query).notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(searchQueryProvider);
    final animeState = ref.watch(filteredAnimeListProvider);
    final isOffline = ref.watch(isOfflineProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Offline banner
            if (isOffline) const OfflineBanner(),
            // Search bar
            _buildSearchBar(),
            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppColors.accentOlive,
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Today's updates section (only when not searching)
                    if (searchQuery.isEmpty) _buildTodayUpdatesSection(),
                    // Main anime list
                    _buildAnimeListSection(animeState),
                    // Loading more indicator
                    if (animeState.isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accentOlive,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
        AppSpacing.pageHorizontal,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: AppTypography.bodyMedium,
        decoration: InputDecoration(
          hintText: '搜索动漫...',
          hintStyle: AppTypography.bodyMedium.copyWith(
            color: AppColors.textTertiary,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textTertiary,
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  onPressed: _onSearchClear,
                )
              : null,
          filled: true,
          fillColor: AppColors.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.accentOlive),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayUpdatesSection() {
    final todayUpdates = ref.watch(todayUpdatesProvider);

    return SliverToBoxAdapter(
      child: todayUpdates.when(
        data: (animes) {
          if (animes.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.md,
                  AppSpacing.pageHorizontal,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.accentTerracotta,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    AppSpacing.horizontalSm,
                    Text('今日更新', style: AppTypography.headlineSmall),
                  ],
                ),
              ),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageHorizontal,
                  ),
                  itemCount: animes.length,
                  separatorBuilder: (_, __) => AppSpacing.horizontalMd,
                  itemBuilder: (context, index) {
                    final anime = animes[index];
                    return AnimeCompactCard(
                      anime: anime,
                      onTap: () => _onAnimeTap(anime),
                      heroTag: 'today_${anime.id}',
                    );
                  },
                ),
              ),
              AppSpacing.verticalMd,
              const Divider(
                height: 1,
                color: AppColors.divider,
                indent: AppSpacing.pageHorizontal,
                endIndent: AppSpacing.pageHorizontal,
              ),
            ],
          );
        },
        loading: _buildTodayUpdatesSkeleton,
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildTodayUpdatesSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.md,
            AppSpacing.pageHorizontal,
            AppSpacing.sm,
          ),
          child: SkeletonLoader.text(width: 80, height: 20),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
            ),
            itemCount: 4,
            separatorBuilder: (_, __) => AppSpacing.horizontalMd,
            itemBuilder: (_, __) => const _CompactCardSkeleton(),
          ),
        ),
        AppSpacing.verticalMd,
      ],
    );
  }

  Widget _buildAnimeListSection(AnimeListState state) {
    // Loading state
    if (state.isLoading && state.animes.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.65,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, __) => const AnimeCardSkeleton(),
            childCount: 6,
          ),
        ),
      );
    }

    // Error state with no cached data
    if (state.error != null && state.animes.isEmpty) {
      return SliverFillRemaining(
        child: ErrorView(message: '加载失败，请重试', onRetry: _onRefresh),
      );
    }

    // Empty state
    if (state.animes.isEmpty && !state.isLoading) {
      final query = ref.read(searchQueryProvider);
      return SliverFillRemaining(
        child: EmptyView(
          icon: Icons.search_off,
          title: query.isEmpty ? '暂无动漫' : '未找到相关动漫',
          message: query.isEmpty ? '稍后再来看看吧' : '试试其他关键词',
        ),
      );
    }

    // Anime grid
    return SliverPadding(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final anime = state.animes[index];
          return AnimeCard(anime: anime, onTap: () => _onAnimeTap(anime));
        }, childCount: state.animes.length),
      ),
    );
  }
}

/// Skeleton for compact anime card.
class _CompactCardSkeleton extends StatelessWidget {
  const _CompactCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader.card(width: 120, height: 160),
          AppSpacing.verticalXs,
          SkeletonLoader.text(width: 100, height: 14),
        ],
      ),
    );
  }
}
