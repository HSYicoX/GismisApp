import 'package:flutter/foundation.dart';

/// WatchRecord model representing a user's watch history entry.
///
/// This model stores the watch progress for an episode along with
/// related anime and episode information for display purposes.
///
/// Requirements: 5.1 - Watch history storage
@immutable
class WatchRecord {
  const WatchRecord({
    required this.id,
    required this.episodeId,
    required this.progress,
    required this.watchedAt,
    this.duration,
    this.completed = false,
    this.episode,
  });

  /// Creates a WatchRecord from JSON (server response).
  factory WatchRecord.fromJson(Map<String, dynamic> json) {
    return WatchRecord(
      id: json['id'] as String,
      episodeId: json['episode_id'] as String,
      progress: json['progress'] as int,
      duration: json['duration'] as int?,
      watchedAt: json['watched_at'] != null
          ? DateTime.parse(json['watched_at'] as String)
          : DateTime.now(),
      completed: json['completed'] as bool? ?? false,
      episode: json['episode'] != null
          ? WatchRecordEpisode.fromJson(json['episode'] as Map<String, dynamic>)
          : null,
    );
  }

  /// The unique identifier of the watch record.
  final String id;

  /// The episode ID being watched.
  final String episodeId;

  /// Current watch progress in seconds.
  final int progress;

  /// Total duration of the episode in seconds.
  final int? duration;

  /// When the episode was last watched.
  final DateTime watchedAt;

  /// Whether the episode has been completed (watched >= 90%).
  final bool completed;

  /// Episode details (populated from nested query).
  final WatchRecordEpisode? episode;

  /// Progress percentage (0.0 to 1.0).
  double get progressPercentage {
    if (duration == null || duration == 0) return 0;
    return (progress / duration!).clamp(0, 1);
  }

  /// Formatted progress string (e.g., "12:34 / 24:00").
  String get formattedProgress {
    final current = _formatDuration(progress);
    if (duration != null) {
      final total = _formatDuration(duration!);
      return '$current / $total';
    }
    return current;
  }

  /// Converts to JSON for API requests.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'episode_id': episodeId,
      'progress': progress,
      if (duration != null) 'duration': duration,
      'watched_at': watchedAt.toIso8601String(),
      'completed': completed,
      if (episode != null) 'episode': episode!.toJson(),
    };
  }

  /// Creates a copy with updated fields.
  WatchRecord copyWith({
    String? id,
    String? episodeId,
    int? progress,
    int? duration,
    DateTime? watchedAt,
    bool? completed,
    WatchRecordEpisode? episode,
  }) {
    return WatchRecord(
      id: id ?? this.id,
      episodeId: episodeId ?? this.episodeId,
      progress: progress ?? this.progress,
      duration: duration ?? this.duration,
      watchedAt: watchedAt ?? this.watchedAt,
      completed: completed ?? this.completed,
      episode: episode ?? this.episode,
    );
  }

  static String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WatchRecord) return false;
    return id == other.id &&
        episodeId == other.episodeId &&
        progress == other.progress &&
        duration == other.duration &&
        watchedAt == other.watchedAt &&
        completed == other.completed &&
        episode == other.episode;
  }

  @override
  int get hashCode => Object.hash(
    id,
    episodeId,
    progress,
    duration,
    watchedAt,
    completed,
    episode,
  );

  @override
  String toString() {
    return 'WatchRecord(id: $id, episodeId: $episodeId, '
        'progress: $progress, completed: $completed)';
  }
}

/// Episode information embedded in watch record.
@immutable
class WatchRecordEpisode {
  const WatchRecordEpisode({
    required this.id,
    required this.seasonId,
    required this.episodeNumber,
    this.title,
    this.synopsis,
    this.durationSeconds,
    this.airDate,
    this.thumbnailUrl,
    this.season,
  });

  factory WatchRecordEpisode.fromJson(Map<String, dynamic> json) {
    return WatchRecordEpisode(
      id: json['id'] as String,
      seasonId: json['season_id'] as String,
      episodeNumber: json['episode_number'] as int,
      title: json['title'] as String?,
      synopsis: json['synopsis'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      airDate: json['air_date'] != null
          ? DateTime.parse(json['air_date'] as String)
          : null,
      thumbnailUrl: json['thumbnail_url'] as String?,
      season: json['season'] != null
          ? WatchRecordSeason.fromJson(json['season'] as Map<String, dynamic>)
          : null,
    );
  }

  final String id;
  final String seasonId;
  final int episodeNumber;
  final String? title;
  final String? synopsis;
  final int? durationSeconds;
  final DateTime? airDate;
  final String? thumbnailUrl;
  final WatchRecordSeason? season;

  /// Display title (e.g., "第1集" or "第1集 标题").
  String get displayTitle {
    if (title != null && title!.isNotEmpty) {
      return '第$episodeNumber集 $title';
    }
    return '第$episodeNumber集';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'season_id': seasonId,
      'episode_number': episodeNumber,
      if (title != null) 'title': title,
      if (synopsis != null) 'synopsis': synopsis,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (airDate != null) 'air_date': airDate!.toIso8601String(),
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (season != null) 'season': season!.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WatchRecordEpisode) return false;
    return id == other.id &&
        seasonId == other.seasonId &&
        episodeNumber == other.episodeNumber &&
        title == other.title &&
        synopsis == other.synopsis &&
        durationSeconds == other.durationSeconds &&
        airDate == other.airDate &&
        thumbnailUrl == other.thumbnailUrl &&
        season == other.season;
  }

  @override
  int get hashCode => Object.hash(
    id,
    seasonId,
    episodeNumber,
    title,
    synopsis,
    durationSeconds,
    airDate,
    thumbnailUrl,
    season,
  );
}

/// Season information embedded in watch record episode.
@immutable
class WatchRecordSeason {
  const WatchRecordSeason({
    required this.id,
    required this.animeId,
    required this.seasonNumber,
    this.title,
    this.anime,
  });

  factory WatchRecordSeason.fromJson(Map<String, dynamic> json) {
    return WatchRecordSeason(
      id: json['id'] as String,
      animeId: json['anime_id'] as String,
      seasonNumber: json['season_number'] as int,
      title: json['title'] as String?,
      anime: json['anime'] != null
          ? WatchRecordAnime.fromJson(json['anime'] as Map<String, dynamic>)
          : null,
    );
  }

  final String id;
  final String animeId;
  final int seasonNumber;
  final String? title;
  final WatchRecordAnime? anime;

  /// Display title (e.g., "第1季" or "第1季 标题").
  String get displayTitle {
    if (title != null && title!.isNotEmpty) {
      return '第$seasonNumber季 $title';
    }
    return '第$seasonNumber季';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'anime_id': animeId,
      'season_number': seasonNumber,
      if (title != null) 'title': title,
      if (anime != null) 'anime': anime!.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WatchRecordSeason) return false;
    return id == other.id &&
        animeId == other.animeId &&
        seasonNumber == other.seasonNumber &&
        title == other.title &&
        anime == other.anime;
  }

  @override
  int get hashCode => Object.hash(id, animeId, seasonNumber, title, anime);
}

/// Anime information embedded in watch record season.
@immutable
class WatchRecordAnime {
  const WatchRecordAnime({
    required this.id,
    required this.title,
    this.titleJa,
    this.coverUrl,
    this.status,
  });

  factory WatchRecordAnime.fromJson(Map<String, dynamic> json) {
    return WatchRecordAnime(
      id: json['id'] as String,
      title: json['title'] as String,
      titleJa: json['title_ja'] as String?,
      coverUrl: json['cover_url'] as String?,
      status: json['status'] as String?,
    );
  }

  final String id;
  final String title;
  final String? titleJa;
  final String? coverUrl;
  final String? status;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (titleJa != null) 'title_ja': titleJa,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (status != null) 'status': status,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WatchRecordAnime) return false;
    return id == other.id &&
        title == other.title &&
        titleJa == other.titleJa &&
        coverUrl == other.coverUrl &&
        status == other.status;
  }

  @override
  int get hashCode => Object.hash(id, title, titleJa, coverUrl, status);
}

/// Request model for updating watch progress.
@immutable
class UpdateProgressRequest {
  const UpdateProgressRequest({
    required this.episodeId,
    required this.progress,
    this.duration,
    this.completed,
  });

  final String episodeId;
  final int progress;
  final int? duration;
  final bool? completed;

  Map<String, dynamic> toJson() {
    return {
      'episode_id': episodeId,
      'progress': progress,
      if (duration != null) 'duration': duration,
      if (completed != null) 'completed': completed,
    };
  }
}
