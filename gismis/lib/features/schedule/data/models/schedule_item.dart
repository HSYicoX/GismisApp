import 'package:flutter/foundation.dart';

import '../../../../shared/models/anime.dart';

/// ScheduleItem model representing an anime entry in the weekly schedule.
///
/// This model is used for Supabase-based schedule data, containing
/// the anime information along with its airing schedule details.
///
/// The [dayOfWeek] follows the database convention:
/// - 0 = Sunday
/// - 1 = Monday
/// - 2 = Tuesday
/// - 3 = Wednesday
/// - 4 = Thursday
/// - 5 = Friday
/// - 6 = Saturday
@immutable
class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.animeId,
    required this.dayOfWeek,
    required this.airTime,
    required this.timezone,
    this.anime,
    this.seasonId,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a ScheduleItem from JSON data.
  ///
  /// Supports nested anime data from PostgREST joins.
  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: json['id'] as String,
      animeId: json['anime_id'] as String,
      dayOfWeek: json['day_of_week'] as int,
      airTime: json['air_time'] as String,
      timezone: json['timezone'] as String? ?? 'Asia/Shanghai',
      anime: json['anime'] != null
          ? Anime.fromJson(json['anime'] as Map<String, dynamic>)
          : null,
      seasonId: json['season_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Unique identifier for the schedule entry.
  final String id;

  /// The anime ID this schedule belongs to.
  final String animeId;

  /// Day of week (0=Sunday, 1=Monday, ..., 6=Saturday).
  final int dayOfWeek;

  /// Time of day when the anime airs (format: "HH:mm:ss").
  final String airTime;

  /// Timezone for the air time (e.g., "Asia/Shanghai", "Asia/Tokyo").
  final String timezone;

  /// The anime details (populated via PostgREST join).
  final Anime? anime;

  /// Optional season ID if this schedule is for a specific season.
  final String? seasonId;

  /// Whether this schedule entry is currently active.
  final bool isActive;

  /// When this schedule entry was created.
  final DateTime? createdAt;

  /// When this schedule entry was last updated.
  final DateTime? updatedAt;

  /// Converts this ScheduleItem to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'anime_id': animeId,
      'day_of_week': dayOfWeek,
      'air_time': airTime,
      'timezone': timezone,
      if (anime != null) 'anime': anime!.toJson(),
      if (seasonId != null) 'season_id': seasonId,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Creates a copy of this ScheduleItem with the given fields replaced.
  ScheduleItem copyWith({
    String? id,
    String? animeId,
    int? dayOfWeek,
    String? airTime,
    String? timezone,
    Anime? anime,
    String? seasonId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScheduleItem(
      id: id ?? this.id,
      animeId: animeId ?? this.animeId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      airTime: airTime ?? this.airTime,
      timezone: timezone ?? this.timezone,
      anime: anime ?? this.anime,
      seasonId: seasonId ?? this.seasonId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Converts database day_of_week (0=Sunday) to ISO weekday (1=Monday, 7=Sunday).
  ///
  /// This is useful for compatibility with Dart's DateTime.weekday.
  int get isoWeekday {
    // Database: 0=Sunday, 1=Monday, ..., 6=Saturday
    // ISO: 1=Monday, 2=Tuesday, ..., 7=Sunday
    return dayOfWeek == 0 ? 7 : dayOfWeek;
  }

  /// Parses the air time string to extract hour and minute.
  ///
  /// Returns a record with (hour, minute) or null if parsing fails.
  ({int hour, int minute})? get parsedAirTime {
    final parts = airTime.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return (hour: hour, minute: minute);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ScheduleItem) return false;
    return id == other.id &&
        animeId == other.animeId &&
        dayOfWeek == other.dayOfWeek &&
        airTime == other.airTime &&
        timezone == other.timezone &&
        anime == other.anime &&
        seasonId == other.seasonId &&
        isActive == other.isActive;
  }

  @override
  int get hashCode => Object.hash(
    id,
    animeId,
    dayOfWeek,
    airTime,
    timezone,
    anime,
    seasonId,
    isActive,
  );

  @override
  String toString() {
    return 'ScheduleItem(id: $id, animeId: $animeId, dayOfWeek: $dayOfWeek, '
        'airTime: $airTime, timezone: $timezone, isActive: $isActive)';
  }
}

/// Represents a weekly schedule grouped by day of week.
///
/// Keys are ISO weekday numbers (1=Monday, 7=Sunday).
typedef WeeklySchedule = Map<int, List<ScheduleItem>>;

/// Extension methods for WeeklySchedule.
extension WeeklyScheduleExtension on WeeklySchedule {
  /// Gets the schedule items for a specific ISO weekday.
  ///
  /// Returns an empty list if no items exist for that day.
  List<ScheduleItem> forWeekday(int isoWeekday) {
    return this[isoWeekday] ?? [];
  }

  /// Gets the total number of schedule items across all days.
  int get totalItems {
    return values.fold(0, (sum, items) => sum + items.length);
  }

  /// Checks if the schedule has no items on any day.
  ///
  /// Note: This is different from Map.isEmpty which checks if the map has no keys.
  /// This method checks if all the lists in the map are empty.
  bool get hasNoItems {
    return values.every((items) => items.isEmpty);
  }

  /// Checks if the schedule has any items on any day.
  ///
  /// Note: This is different from Map.isNotEmpty which checks if the map has keys.
  /// This method checks if any list in the map has items.
  bool get hasItems => !hasNoItems;
}
