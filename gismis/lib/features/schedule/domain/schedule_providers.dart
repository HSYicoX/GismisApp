import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../shared/models/schedule_entry.dart';
import '../data/schedule_repository.dart';
import '../data/schedule_repository.dart' as schedule_repository;

/// Provider for the ScheduleRepository instance.
final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final supabaseClient = ref.watch(supabaseClientProvider);
  return ScheduleRepository(supabaseClient: supabaseClient);
});

/// Provider for the currently selected weekday (1=Monday, 7=Sunday).
final weekdayProvider = StateProvider<int>((ref) {
  // Default to current day of week
  final now = DateTime.now();
  // DateTime.weekday returns 1 for Monday, 7 for Sunday
  return now.weekday;
});

/// State class for schedule data.
class ScheduleState {
  const ScheduleState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
    this.weekday = 1,
  });
  final List<ScheduleEntry> entries;
  final bool isLoading;
  final String? error;
  final int weekday;

  ScheduleState copyWith({
    List<ScheduleEntry>? entries,
    bool? isLoading,
    String? error,
    int? weekday,
  }) {
    return ScheduleState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      weekday: weekday ?? this.weekday,
    );
  }
}

/// StateNotifier for managing schedule data with followed anime priority.
class ScheduleNotifier extends StateNotifier<ScheduleState> {
  ScheduleNotifier(this._repository, this._weekday)
    : super(ScheduleState(weekday: _weekday));
  final ScheduleRepository _repository;
  final int _weekday;

  /// Loads schedule entries for the current weekday.
  Future<void> load() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      final entries = await _repository.getScheduleByWeekday(_weekday);

      // Sort with followed anime first
      final sorted = sortByFollowedFirst(entries);

      // Try to apply custom order
      try {
        final customOrder = await _repository.getUserOrder(_weekday);
        if (customOrder != null && customOrder.isNotEmpty) {
          final ordered = applyCustomOrder(sorted, customOrder);
          state = state.copyWith(entries: ordered, isLoading: false);
          return;
        }
      } catch (_) {
        // Ignore custom order errors, use default sorting
      }

      state = state.copyWith(entries: sorted, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refreshes the schedule data.
  Future<void> refresh() async {
    state = state.copyWith(entries: []);
    await load();
  }

  /// Updates the progress for an anime.
  Future<void> incrementProgress(String animeId) async {
    final entryIndex = state.entries.indexWhere((e) => e.anime.id == animeId);

    if (entryIndex == -1) return;

    final entry = state.entries[entryIndex];
    final currentProgress = entry.userFollow?.progressEpisode ?? 0;
    final newProgress = schedule_repository.incrementProgress(
      currentProgress,
      entry.latestEpisode,
    );

    // Don't update if already at max
    if (newProgress == currentProgress) return;

    try {
      await _repository.updateProgress(animeId, newProgress);

      // Update local state
      final updatedEntries = List<ScheduleEntry>.from(state.entries);
      if (entry.userFollow != null) {
        updatedEntries[entryIndex] = entry.copyWith(
          userFollow: entry.userFollow!.copyWith(progressEpisode: newProgress),
        );
      }

      state = state.copyWith(entries: updatedEntries);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Reorders entries and persists the new order.
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    final entries = List<ScheduleEntry>.from(state.entries);
    final item = entries.removeAt(oldIndex);

    // Adjust newIndex if needed after removal
    final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    entries.insert(adjustedIndex, item);

    // Update local state immediately for responsive UI
    state = state.copyWith(entries: entries);

    // Persist the new order
    try {
      final animeIds = entries.map((e) => e.anime.id).toList();
      await _repository.updateUserOrder(_weekday, animeIds);
    } catch (e) {
      // Revert on error
      await load();
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Provider for schedule data for a specific weekday.
final scheduleProvider =
    StateNotifierProvider.family<ScheduleNotifier, ScheduleState, int>((
      ref,
      weekday,
    ) {
      final repository = ref.watch(scheduleRepositoryProvider);
      final notifier = ScheduleNotifier(repository, weekday)..load();
      return notifier;
    });

/// Provider for the current weekday's schedule.
final currentScheduleProvider = Provider<ScheduleState>((ref) {
  final weekday = ref.watch(weekdayProvider);
  return ref.watch(scheduleProvider(weekday));
});

/// State class for user's custom order per weekday.
class UserOrderState {
  const UserOrderState({
    this.orders = const {},
    this.isLoading = false,
    this.error,
  });
  final Map<int, List<String>> orders;
  final bool isLoading;
  final String? error;

  UserOrderState copyWith({
    Map<int, List<String>>? orders,
    bool? isLoading,
    String? error,
  }) {
    return UserOrderState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Gets the order for a specific weekday.
  List<String>? getOrder(int weekday) => orders[weekday];
}

/// StateNotifier for managing user's custom order across all weekdays.
class UserOrderNotifier extends StateNotifier<UserOrderState> {
  UserOrderNotifier(this._repository) : super(const UserOrderState());
  final ScheduleRepository _repository;

  /// Loads the custom order for a specific weekday.
  Future<void> loadOrder(int weekday) async {
    try {
      final order = await _repository.getUserOrder(weekday);
      if (order != null) {
        final newOrders = Map<int, List<String>>.from(state.orders);
        newOrders[weekday] = order;
        state = state.copyWith(orders: newOrders);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Updates the custom order for a specific weekday.
  Future<void> updateOrder(int weekday, List<String> animeIds) async {
    try {
      await _repository.updateUserOrder(weekday, animeIds);

      final newOrders = Map<int, List<String>>.from(state.orders);
      newOrders[weekday] = animeIds;
      state = state.copyWith(orders: newOrders);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Provider for user's custom order state.
final userOrderProvider =
    StateNotifierProvider<UserOrderNotifier, UserOrderState>((ref) {
      final repository = ref.watch(scheduleRepositoryProvider);
      return UserOrderNotifier(repository);
    });

/// Weekday names for display.
const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Short weekday names for tabs.
const weekdayShortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Gets the display name for a weekday (1-7).
String getWeekdayName(int weekday) {
  if (weekday < 1 || weekday > 7) return '';
  return weekdayNames[weekday - 1];
}

/// Gets the short display name for a weekday (1-7).
String getWeekdayShortName(int weekday) {
  if (weekday < 1 || weekday > 7) return '';
  return weekdayShortNames[weekday - 1];
}
