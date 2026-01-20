import 'package:meta/meta.dart';

import 'episode.dart';

/// AnimeSeason model representing a season of an anime series.
///
/// This model maps to the `anime_seasons` table in the database and
/// supports nested episodes parsing from PostgREST queries.
@immutable
class AnimeSeason {
  const AnimeSeason({
    required this.id,
    required this.animeId,
    required this.seasonNumber,
    this.title,
    this.episodeCount = 0,
    this.latestEpisode,
    required this.status,
    this.startDate,
    this.endDate,
    this.episodes,
    this.createdAt,
    this.updatedAt,
  });

  factory AnimeSeason.fromJson(Map<String, dynamic> json) {
    return AnimeSeason(
      id: json['id'] as String,
      animeId: json['anime_id'] as String,
      seasonNumber: json['season_number'] as int,
      title: json['title'] as String?,
      episodeCount: json['episode_count'] as int? ?? 0,
      latestEpisode: json['latest_episode'] as int?,
      status: AnimeSeasonStatus.fromString(json['status'] as String),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      episodes: json['episodes'] != null
          ? (json['episodes'] as List)
                .map((e) => Episode.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Unique identifier (UUID)
  final String id;

  /// Reference to parent anime
  final String animeId;

  /// Season number (1, 2, 3, etc.)
  final int seasonNumber;

  /// Season title (e.g., "第二季", "完结篇")
  final String? title;

  /// Total episode count for this season
  final int episodeCount;

  /// Latest episode number in this season
  final int? latestEpisode;

  /// Season airing status
  final AnimeSeasonStatus status;

  /// Season start date
  final DateTime? startDate;

  /// Season end date
  final DateTime? endDate;

  /// Episodes list (from nested query)
  final List<Episode>? episodes;

  /// Record creation timestamp
  final DateTime? createdAt;

  /// Record update timestamp
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'anime_id': animeId,
      'season_number': seasonNumber,
      'title': title,
      'episode_count': episodeCount,
      'latest_episode': latestEpisode,
      'status': status.value,
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      if (episodes != null)
        'episodes': episodes!.map((e) => e.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  AnimeSeason copyWith({
    String? id,
    String? animeId,
    int? seasonNumber,
    String? title,
    int? episodeCount,
    int? latestEpisode,
    AnimeSeasonStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    List<Episode>? episodes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AnimeSeason(
      id: id ?? this.id,
      animeId: animeId ?? this.animeId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      title: title ?? this.title,
      episodeCount: episodeCount ?? this.episodeCount,
      latestEpisode: latestEpisode ?? this.latestEpisode,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      episodes: episodes ?? this.episodes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnimeSeason) return false;
    return id == other.id &&
        animeId == other.animeId &&
        seasonNumber == other.seasonNumber &&
        title == other.title &&
        episodeCount == other.episodeCount &&
        latestEpisode == other.latestEpisode &&
        status == other.status &&
        startDate == other.startDate &&
        endDate == other.endDate &&
        _listEquals(episodes, other.episodes) &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    animeId,
    seasonNumber,
    title,
    episodeCount,
    latestEpisode,
    status,
    startDate,
    endDate,
    episodes != null ? Object.hashAll(episodes!) : null,
    createdAt,
    updatedAt,
  );

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Anime season status enum.
enum AnimeSeasonStatus {
  airing('airing'),
  completed('completed'),
  upcoming('upcoming');

  const AnimeSeasonStatus(this.value);

  final String value;

  static AnimeSeasonStatus fromString(String value) {
    return AnimeSeasonStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AnimeSeasonStatus.upcoming,
    );
  }
}
