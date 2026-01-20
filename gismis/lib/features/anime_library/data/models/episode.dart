import 'package:meta/meta.dart';

/// Episode model representing an episode of an anime season.
///
/// This model maps to the `episodes` table in the database and
/// supports nested platform_links parsing from PostgREST queries.
@immutable
class Episode {
  const Episode({
    required this.id,
    required this.seasonId,
    required this.episodeNumber,
    this.title,
    this.synopsis,
    this.duration,
    this.airDate,
    this.thumbnailUrl,
    this.platformLinks,
    this.createdAt,
    this.updatedAt,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    // Parse platform links from nested query (episode_platform_links)
    Map<String, String>? links;
    if (json['episode_platform_links'] != null) {
      links = Map.fromEntries(
        (json['episode_platform_links'] as List).map(
          (e) => MapEntry(e['platform'] as String, e['url'] as String),
        ),
      );
    }

    return Episode(
      id: json['id'] as String,
      seasonId: json['season_id'] as String,
      episodeNumber: json['episode_number'] as int,
      title: json['title'] as String?,
      synopsis: json['synopsis'] as String?,
      duration: json['duration_seconds'] != null
          ? Duration(seconds: json['duration_seconds'] as int)
          : null,
      airDate: json['air_date'] != null
          ? DateTime.parse(json['air_date'] as String)
          : null,
      thumbnailUrl: json['thumbnail_url'] as String?,
      platformLinks: links,
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

  /// Reference to parent season
  final String seasonId;

  /// Episode number within the season
  final int episodeNumber;

  /// Episode title
  final String? title;

  /// Episode synopsis/description
  final String? synopsis;

  /// Episode duration
  final Duration? duration;

  /// Air date of the episode
  final DateTime? airDate;

  /// Thumbnail image URL
  final String? thumbnailUrl;

  /// Platform links (platform -> url)
  final Map<String, String>? platformLinks;

  /// Record creation timestamp
  final DateTime? createdAt;

  /// Record update timestamp
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'season_id': seasonId,
      'episode_number': episodeNumber,
      'title': title,
      'synopsis': synopsis,
      'duration_seconds': duration?.inSeconds,
      'air_date': airDate?.toIso8601String().split('T').first,
      'thumbnail_url': thumbnailUrl,
      if (platformLinks != null)
        'episode_platform_links': platformLinks!.entries
            .map((e) => {'platform': e.key, 'url': e.value})
            .toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Episode copyWith({
    String? id,
    String? seasonId,
    int? episodeNumber,
    String? title,
    String? synopsis,
    Duration? duration,
    DateTime? airDate,
    String? thumbnailUrl,
    Map<String, String>? platformLinks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Episode(
      id: id ?? this.id,
      seasonId: seasonId ?? this.seasonId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      synopsis: synopsis ?? this.synopsis,
      duration: duration ?? this.duration,
      airDate: airDate ?? this.airDate,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      platformLinks: platformLinks ?? this.platformLinks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Episode) return false;
    return id == other.id &&
        seasonId == other.seasonId &&
        episodeNumber == other.episodeNumber &&
        title == other.title &&
        synopsis == other.synopsis &&
        duration == other.duration &&
        airDate == other.airDate &&
        thumbnailUrl == other.thumbnailUrl &&
        _mapEquals(platformLinks, other.platformLinks) &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    seasonId,
    episodeNumber,
    title,
    synopsis,
    duration,
    airDate,
    thumbnailUrl,
    platformLinks != null ? Object.hashAll(platformLinks!.entries) : null,
    createdAt,
    updatedAt,
  );

  static bool _mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
