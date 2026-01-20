import '../../../core/network/api_exception.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/models/schedule_entry.dart';

/// Repository for schedule-related data operations.
///
/// Handles fetching weekly schedule data from the get-schedule Edge Function
/// which aggregates data from multiple platforms (Bilibili, TMDB, etc.).
class ScheduleRepository {
  ScheduleRepository({required SupabaseClient supabaseClient})
    : _supabaseClient = supabaseClient;
  final SupabaseClient _supabaseClient;

  /// Fetches the schedule for a specific weekday from the Edge Function.
  ///
  /// This calls the `get-schedule` Edge Function which aggregates schedule data
  /// from multiple platforms and returns merged results.
  ///
  /// [weekday] - Day of the week (1=Monday, 7=Sunday)
  ///
  /// Returns a list of [ScheduleEntry] for the specified day.
  Future<List<ScheduleEntry>> getScheduleByWeekday(int weekday) async {
    assert(weekday >= 1 && weekday <= 7, 'Weekday must be between 1 and 7');

    try {
      final response = await _supabaseClient
          .callPublicFunctionGet<Map<String, dynamic>>(
            'get-schedule',
            queryParameters: {'day': weekday.toString()},
          );

      final data = response.data;
      if (data == null || data['success'] != true) {
        throw ApiException(
          type: ApiErrorType.serverError,
          message:
              (data?['error']?['message'] as String?) ??
              'Failed to fetch schedule',
          statusCode: response.statusCode ?? 500,
        );
      }

      final scheduleData = data['data'] as Map<String, dynamic>?;
      final scheduleList = scheduleData?['schedule'] as List<dynamic>? ?? [];

      return scheduleList
          .map((e) => _scheduleEntryFromEdgeFunction(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    }
  }

  /// Fetches the full weekly schedule from the Edge Function.
  ///
  /// Returns a map with weekday (1-7) as key and list of entries as value.
  Future<Map<int, List<ScheduleEntry>>> getWeeklySchedule() async {
    try {
      final response = await _supabaseClient
          .callPublicFunctionGet<Map<String, dynamic>>('get-schedule');

      final data = response.data;
      if (data == null || data['success'] != true) {
        throw ApiException(
          type: ApiErrorType.serverError,
          message:
              (data?['error']?['message'] as String?) ??
              'Failed to fetch schedule',
          statusCode: response.statusCode ?? 500,
        );
      }

      final scheduleData = data['data'] as Map<String, dynamic>?;
      final scheduleList = scheduleData?['schedule'] as List<dynamic>? ?? [];

      // Group by weekday
      final grouped = <int, List<ScheduleEntry>>{};
      for (var i = 1; i <= 7; i++) {
        grouped[i] = [];
      }

      for (final item in scheduleList) {
        final entry = _scheduleEntryFromEdgeFunction(
          item as Map<String, dynamic>,
        );
        final updateDay = (item['updateDay'] as int?) ?? 1;
        if (updateDay >= 1 && updateDay <= 7) {
          grouped[updateDay]!.add(entry);
        }
      }

      return grouped;
    } on ApiException {
      rethrow;
    }
  }

  /// Converts Edge Function AnimeInfo JSON to ScheduleEntry model.
  static ScheduleEntry _scheduleEntryFromEdgeFunction(
    Map<String, dynamic> json,
  ) {
    return ScheduleEntry(
      anime: _animeFromEdgeFunction(json),
      latestEpisode: (json['latestEpisode'] as int?) ?? 0,
      userFollow: null, // User follow data requires authentication
    );
  }

  /// Converts Edge Function AnimeInfo JSON to Anime model.
  static Anime _animeFromEdgeFunction(Map<String, dynamic> json) {
    return Anime(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      titleAlias: _parseStringList(json['titleAliases']),
      coverUrl: json['coverUrl'] as String? ?? '',
      summary: json['synopsis'] as String?,
      status: _parseEdgeFunctionStatus(json['status'] as String?),
      updatedAt: DateTime.now(), // Edge function doesn't provide this
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  static AnimeStatus _parseEdgeFunctionStatus(String? status) {
    if (status == null) return AnimeStatus.ongoing;
    return switch (status.toLowerCase()) {
      'ongoing' => AnimeStatus.ongoing,
      'completed' => AnimeStatus.completed,
      'upcoming' => AnimeStatus.upcoming,
      _ => AnimeStatus.ongoing,
    };
  }

  /// Updates the user's custom order for anime on a specific weekday.
  /// Note: This requires authentication and is not yet implemented for Supabase.
  ///
  /// [weekday] - Day of the week (1=Monday, 7=Sunday)
  /// [animeIds] - Ordered list of anime IDs representing the custom order
  Future<void> updateUserOrder(int weekday, List<String> animeIds) async {
    assert(weekday >= 1 && weekday <= 7, 'Weekday must be between 1 and 7');
    // TODO: Implement via Edge Function when user authentication is ready
  }

  /// Updates the user's progress for a specific anime.
  /// Note: This requires authentication and is not yet implemented for Supabase.
  ///
  /// [animeId] - The ID of the anime to update
  /// [episode] - The new episode number
  Future<void> updateProgress(String animeId, int episode) async {
    assert(episode >= 0, 'Episode must be non-negative');
    // TODO: Implement via Edge Function when user authentication is ready
  }

  /// Gets the user's custom order for a specific weekday.
  /// Note: This requires authentication and is not yet implemented for Supabase.
  ///
  /// [weekday] - Day of the week (1=Monday, 7=Sunday)
  ///
  /// Returns a list of anime IDs in the user's custom order,
  /// or null if no custom order is set.
  Future<List<String>?> getUserOrder(int weekday) async {
    assert(weekday >= 1 && weekday <= 7, 'Weekday must be between 1 and 7');
    // TODO: Implement via Edge Function when user authentication is ready
    return null;
  }
}

/// Utility function to group schedule entries by weekday.
///
/// This is a pure function useful for property-based testing.
///
/// [entries] - List of schedule entries with anime that have schedule info
/// [getWeekday] - Function to extract weekday from an entry (handles overrides)
///
/// Returns a map with weekday (1-7) as key and list of entries as value.
Map<int, List<ScheduleEntry>> groupScheduleByWeekday(
  List<ScheduleEntry> entries,
  int Function(ScheduleEntry) getWeekday,
) {
  final grouped = <int, List<ScheduleEntry>>{};

  // Initialize all 7 days
  for (var i = 1; i <= 7; i++) {
    grouped[i] = [];
  }

  for (final entry in entries) {
    final weekday = getWeekday(entry);
    if (weekday >= 1 && weekday <= 7) {
      grouped[weekday]!.add(entry);
    }
  }

  return grouped;
}

/// Utility function to sort schedule entries with followed anime first.
///
/// This is a pure function useful for property-based testing.
///
/// [entries] - List of schedule entries to sort
///
/// Returns a new list with followed anime before unfollowed anime.
List<ScheduleEntry> sortByFollowedFirst(List<ScheduleEntry> entries) {
  final followed = <ScheduleEntry>[];
  final unfollowed = <ScheduleEntry>[];

  for (final entry in entries) {
    if (entry.userFollow != null) {
      followed.add(entry);
    } else {
      unfollowed.add(entry);
    }
  }

  return [...followed, ...unfollowed];
}

/// Utility function to increment progress safely.
///
/// This is a pure function useful for property-based testing.
///
/// [currentProgress] - Current episode progress
/// [latestEpisode] - Latest available episode
///
/// Returns the new progress value, capped at latestEpisode.
int incrementProgress(int currentProgress, int latestEpisode) {
  final newProgress = currentProgress + 1;
  return newProgress > latestEpisode ? latestEpisode : newProgress;
}

/// Utility function to apply custom order to schedule entries.
///
/// [entries] - List of schedule entries to reorder
/// [customOrder] - List of anime IDs in desired order
///
/// Returns entries sorted according to custom order.
/// Entries not in customOrder are appended at the end.
List<ScheduleEntry> applyCustomOrder(
  List<ScheduleEntry> entries,
  List<String> customOrder,
) {
  if (customOrder.isEmpty) return entries;

  final orderMap = <String, int>{};
  for (var i = 0; i < customOrder.length; i++) {
    orderMap[customOrder[i]] = i;
  }

  final sorted = List<ScheduleEntry>.from(entries)
    ..sort((a, b) {
      final aIndex = orderMap[a.anime.id];
      final bIndex = orderMap[b.anime.id];

      // Both in custom order - sort by order
      if (aIndex != null && bIndex != null) {
        return aIndex.compareTo(bIndex);
      }

      // Only a in custom order - a comes first
      if (aIndex != null) return -1;

      // Only b in custom order - b comes first
      if (bIndex != null) return 1;

      // Neither in custom order - maintain original order
      return 0;
    });

  return sorted;
}
