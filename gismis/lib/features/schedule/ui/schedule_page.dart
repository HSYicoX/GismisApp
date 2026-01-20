import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../domain/schedule_providers.dart';
import 'widgets/schedule_entry_tile.dart';

/// The weekly schedule page displaying anime updates organized by weekday.
///
/// Features:
/// - Weekday tabs (Mon-Sun)
/// - Followed anime priority sorting
/// - Progress tracking with increment button
/// - Drag-to-reorder functionality
/// - Loading, error, and empty states
class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isReorderMode = false;

  @override
  void initState() {
    super.initState();
    // Initialize tab controller with current weekday
    final currentWeekday = ref.read(weekdayProvider);
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: currentWeekday - 1,
    );

    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      ref.read(weekdayProvider.notifier).state = _tabController.index + 1;
      // Exit reorder mode when changing tabs
      if (_isReorderMode) {
        setState(() => _isReorderMode = false);
      }
    }
  }

  void _toggleReorderMode() {
    setState(() => _isReorderMode = !_isReorderMode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(7, (index) {
          final weekday = index + 1;
          return _ScheduleDayView(
            weekday: weekday,
            isReorderMode: _isReorderMode,
          );
        }),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      title: Text(
        '每周更新',
        style: AppTypography.headlineMedium.copyWith(
          fontFamily: AppTypography.titleFontFamily,
        ),
      ),
      actions: [
        // Reorder mode toggle
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
        preferredSize: const Size.fromHeight(48),
        child: _buildWeekdayTabs(),
      ),
    );
  }

  Widget _buildWeekdayTabs() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.accentOlive,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTypography.labelMedium,
        indicatorColor: AppColors.accentOlive,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        tabs: List.generate(7, (index) {
          final weekday = index + 1;
          final isToday = DateTime.now().weekday == weekday;
          return Tab(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(getWeekdayShortName(weekday)),
                if (isToday)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.accentTerracotta,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// View for a single day's schedule.
class _ScheduleDayView extends ConsumerWidget {
  const _ScheduleDayView({required this.weekday, required this.isReorderMode});

  final int weekday;
  final bool isReorderMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleState = ref.watch(scheduleProvider(weekday));

    if (scheduleState.isLoading && scheduleState.entries.isEmpty) {
      return _buildLoadingState();
    }

    if (scheduleState.error != null && scheduleState.entries.isEmpty) {
      return _buildErrorState(context, ref, scheduleState.error!);
    }

    if (scheduleState.entries.isEmpty) {
      return _buildEmptyState();
    }

    return _buildScheduleList(context, ref, scheduleState);
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      itemCount: 5,
      itemBuilder: (context, index) => const ScheduleEntryTileSkeleton(),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: ErrorView(
        title: '加载失败',
        message: error,
        onRetry: () {
          ref.read(scheduleProvider(weekday).notifier).refresh();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: EmptyView(
        icon: Icons.calendar_today_outlined,
        title: '今日无更新',
        message: '${getWeekdayName(weekday)}没有番剧更新',
      ),
    );
  }

  Widget _buildScheduleList(
    BuildContext context,
    WidgetRef ref,
    ScheduleState state,
  ) {
    if (isReorderMode) {
      return _buildReorderableList(context, ref, state);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(scheduleProvider(weekday).notifier).refresh();
      },
      color: AppColors.accentOlive,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        itemCount: state.entries.length,
        itemBuilder: (context, index) {
          final entry = state.entries[index];
          return ScheduleEntryTile(
            entry: entry,
            onTap: () => _navigateToDetail(context, entry.anime.id),
            onIncrementProgress: () {
              ref
                  .read(scheduleProvider(weekday).notifier)
                  .incrementProgress(entry.anime.id);
            },
            heroTag: 'schedule_${weekday}_${entry.anime.id}',
          );
        },
      ),
    );
  }

  Widget _buildReorderableList(
    BuildContext context,
    WidgetRef ref,
    ScheduleState state,
  ) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      itemCount: state.entries.length,
      onReorder: (oldIndex, newIndex) {
        ref
            .read(scheduleProvider(weekday).notifier)
            .reorder(oldIndex, newIndex);
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
        final entry = state.entries[index];
        return ScheduleEntryTile(
          key: ValueKey(entry.anime.id),
          entry: entry,
          isReorderMode: true,
          heroTag: 'schedule_${weekday}_${entry.anime.id}',
        );
      },
    );
  }

  void _navigateToDetail(BuildContext context, String animeId) {
    context.push('/anime/$animeId');
  }
}
