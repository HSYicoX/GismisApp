/// Supabase Schedule Repository for PostgREST queries.
///
/// This repository handles public read operations for anime schedule data
/// using PostgREST direct queries with RLS public access.
///
/// Features:
/// - Weekly schedule grouped by day of week
/// - Timezone conversion support
/// - 1-hour TTL caching via Hive
library;

import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../core/supabase/supabase_client.dart';
import 'models/schedule_item.dart';

/// Repository for anime schedule data operations via Supabase.
///
/// Access mode: PostgREST direct connection (public read-only, RLS allows)
///
/// The schedule data follows the database convention for day_of_week:
/// - 0 = Sunday
/// - 1 = Monday
/// - 2 = Tuesday
/// - 3 = Wednesday
/// - 4 = Thursday
/// - 5 = Friday
/// - 6 = Saturday
///
/// However, the [getWeeklySchedule] method returns data grouped by ISO weekday:
/// - 1 = Monday
/// - 2 = Tuesday
/// - ...
/// - 7 = Sunday
class SupabaseScheduleRepository {
  SupabaseScheduleRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  static const _cacheBoxName = 'schedule_cache';
  static const _cacheKey = 'weekly_schedule';
  static const _cacheTimestampKey = 'weekly_schedule_timestamp';
  static const _cacheTtl = Duration(hours: 1);

  Box<String>? _cacheBox;

  /// Initializes the cache box.
  ///
  /// Call this before using cache-related methods.
  Future<void> initCache() async {
    _cacheBox ??= await Hive.openBox<String>(_cacheBoxName);
  }

  /// Fetches the weekly schedule grouped by ISO weekday.
  ///
  /// Parameters:
  /// - [userTimezone]: User's timezone for time conversion (default: 'Asia/Shanghai')
  /// - [forceRefresh]: If true, bypasses cache and fetches fresh data
  ///
  /// Returns a [WeeklySchedule] map with ISO weekday (1-7) as keys.
  ///
  /// The method:
  /// 1. Checks cache first (if not forceRefresh)
  /// 2. Fetches from Supabase if cache is stale or missing
  /// 3. Groups results by ISO weekday
  /// 4. Sorts each day's items by air time
  /// 5. Caches the result with 1-hour TTL
  Future<WeeklySchedule> getWeeklySchedule({
    String userTimezone = 'Asia/Shanghai',
    bool forceRefresh = false,
  }) async {
    // Try cache first
    if (!forceRefresh) {
      final cached = await _getCachedSchedule();
      if (cached != null) {
        return cached;
      }
    }

    // Fetch from Supabase
    final result = await _client.query<ScheduleItem>(
      table: 'schedule',
      fromJson: ScheduleItem.fromJson,
      select: '*, anime(*)',
      filters: {'is_active': 'eq.true'},
      order: 'day_of_week.asc,air_time.asc',
      countTotal: false,
    );

    // Group by ISO weekday
    final grouped = groupScheduleByIsoWeekday(result.items);

    // Apply timezone conversion if needed
    final converted = _applyTimezoneConversion(grouped, userTimezone);

    // Cache the result
    await _cacheSchedule(converted);

    return converted;
  }

  /// Fetches schedule items for a specific ISO weekday.
  ///
  /// Parameters:
  /// - [isoWeekday]: ISO weekday number (1=Monday, 7=Sunday)
  /// - [userTimezone]: User's timezone for time conversion
  ///
  /// Returns a list of [ScheduleItem] for the specified day.
  Future<List<ScheduleItem>> getScheduleForDay(
    int isoWeekday, {
    String userTimezone = 'Asia/Shanghai',
  }) async {
    assert(
      isoWeekday >= 1 && isoWeekday <= 7,
      'ISO weekday must be between 1 and 7',
    );

    // Convert ISO weekday to database day_of_week
    final dbDayOfWeek = isoWeekdayToDbDayOfWeek(isoWeekday);

    final result = await _client.query<ScheduleItem>(
      table: 'schedule',
      fromJson: ScheduleItem.fromJson,
      select: '*, anime(*)',
      filters: {'day_of_week': 'eq.$dbDayOfWeek', 'is_active': 'eq.true'},
      order: 'air_time.asc',
      countTotal: false,
    );

    return result.items;
  }

  /// Fetches today's schedule based on the current date.
  ///
  /// Parameters:
  /// - [userTimezone]: User's timezone for time conversion
  ///
  /// Returns a list of [ScheduleItem] for today.
  Future<List<ScheduleItem>> getTodaySchedule({
    String userTimezone = 'Asia/Shanghai',
  }) async {
    final today = DateTime.now().weekday; // ISO weekday (1-7)
    return getScheduleForDay(today, userTimezone: userTimezone);
  }

  /// Clears the schedule cache.
  Future<void> clearCache() async {
    await initCache();
    await _cacheBox!.clear();
  }

  /// Checks if the cache is stale (older than TTL).
  Future<bool> isCacheStale() async {
    await initCache();
    final timestampStr = _cacheBox!.get(_cacheTimestampKey);
    if (timestampStr == null) return true;

    try {
      final timestamp = DateTime.parse(timestampStr);
      return DateTime.now().difference(timestamp) > _cacheTtl;
    } on FormatException {
      return true;
    }
  }

  // ============================================================
  // Private Cache Methods
  // ============================================================

  Future<WeeklySchedule?> _getCachedSchedule() async {
    await initCache();

    // Check if cache is stale
    if (await isCacheStale()) {
      return null;
    }

    final jsonString = _cacheBox!.get(_cacheKey);
    if (jsonString == null) return null;

    try {
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final result = <int, List<ScheduleItem>>{};

      for (final entry in jsonMap.entries) {
        final weekday = int.parse(entry.key);
        final items = (entry.value as List<dynamic>)
            .map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
            .toList();
        result[weekday] = items;
      }

      return result;
    } on FormatException {
      return null;
    }
  }

  Future<void> _cacheSchedule(WeeklySchedule schedule) async {
    await initCache();

    final jsonMap = <String, dynamic>{};
    for (final entry in schedule.entries) {
      jsonMap[entry.key.toString()] = entry.value
          .map((item) => item.toJson())
          .toList();
    }

    await _cacheBox!.put(_cacheKey, jsonEncode(jsonMap));
    await _cacheBox!.put(_cacheTimestampKey, DateTime.now().toIso8601String());
  }

  // ============================================================
  // Timezone Conversion
  // ============================================================

  /// Applies timezone conversion to schedule items.
  ///
  /// Currently a placeholder - full timezone conversion would require
  /// a timezone library like `timezone` package.
  WeeklySchedule _applyTimezoneConversion(
    WeeklySchedule schedule,
    String userTimezone,
  ) {
    // For now, we assume all times are in the same timezone
    // Full implementation would convert air_time based on:
    // - item.timezone (source timezone)
    // - userTimezone (target timezone)
    //
    // This might shift items to different days if the time crosses midnight
    return schedule;
  }
}

// ============================================================
// Pure Utility Functions (for testing)
// ============================================================

/// Groups schedule items by ISO weekday.
///
/// This is a pure function useful for property-based testing.
///
/// Parameters:
/// - [items]: List of schedule items to group
///
/// Returns a map with ISO weekday (1-7) as keys and list of items as values.
/// All 7 days are guaranteed to have an entry (empty list if no items).
WeeklySchedule groupScheduleByIsoWeekday(List<ScheduleItem> items) {
  final grouped = <int, List<ScheduleItem>>{};

  // Initialize all 7 days (ISO weekday: 1=Monday, 7=Sunday)
  for (var i = 1; i <= 7; i++) {
    grouped[i] = [];
  }

  for (final item in items) {
    final isoWeekday = item.isoWeekday;
    if (isoWeekday >= 1 && isoWeekday <= 7) {
      grouped[isoWeekday]!.add(item);
    }
  }

  return grouped;
}

/// Converts ISO weekday (1=Monday, 7=Sunday) to database day_of_week (0=Sunday, 6=Saturday).
///
/// This is a pure function useful for property-based testing.
int isoWeekdayToDbDayOfWeek(int isoWeekday) {
  assert(
    isoWeekday >= 1 && isoWeekday <= 7,
    'ISO weekday must be between 1 and 7',
  );
  // ISO: 1=Monday, 2=Tuesday, ..., 7=Sunday
  // DB:  0=Sunday, 1=Monday, ..., 6=Saturday
  return isoWeekday == 7 ? 0 : isoWeekday;
}

/// Converts database day_of_week (0=Sunday, 6=Saturday) to ISO weekday (1=Monday, 7=Sunday).
///
/// This is a pure function useful for property-based testing.
int dbDayOfWeekToIsoWeekday(int dbDayOfWeek) {
  assert(
    dbDayOfWeek >= 0 && dbDayOfWeek <= 6,
    'Database day_of_week must be between 0 and 6',
  );
  // DB:  0=Sunday, 1=Monday, ..., 6=Saturday
  // ISO: 1=Monday, 2=Tuesday, ..., 7=Sunday
  return dbDayOfWeek == 0 ? 7 : dbDayOfWeek;
}

/// Sorts schedule items by air time within each day.
///
/// This is a pure function useful for property-based testing.
///
/// Returns a new WeeklySchedule with items sorted by air_time ascending.
WeeklySchedule sortScheduleByAirTime(WeeklySchedule schedule) {
  final sorted = <int, List<ScheduleItem>>{};

  for (final entry in schedule.entries) {
    final items = List<ScheduleItem>.from(entry.value)
      ..sort((a, b) => a.airTime.compareTo(b.airTime));
    sorted[entry.key] = items;
  }

  return sorted;
}

/// Filters schedule to only include active items.
///
/// This is a pure function useful for property-based testing.
List<ScheduleItem> filterActiveScheduleItems(List<ScheduleItem> items) {
  return items.where((item) => item.isActive).toList();
}
