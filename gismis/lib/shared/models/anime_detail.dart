import 'anime.dart';
import 'anime_platform.dart';
import 'anime_schedule.dart';
import 'anime_episode_state.dart';

/// AnimeDetail model extending Anime with additional detailed information.
class AnimeDetail extends Anime {
  const AnimeDetail({
    required super.id,
    required super.title,
    required super.titleAlias,
    required super.coverUrl,
    required super.status,
    required super.updatedAt,
    required this.platforms,
    super.summary,
    super.platformLinks,
    super.titleAliases,
    this.sourceType,
    this.sourceTitle,
    this.schedule,
    this.episodeState,
    this.aiDigest,
  });

  factory AnimeDetail.fromJson(Map<String, dynamic> json) {
    // Parse platformLinks from JSON (can be null or a map)
    Map<String, String>? platformLinks;
    if (json['platform_links'] != null) {
      platformLinks = (json['platform_links'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      );
    } else if (json['platformLinks'] != null) {
      platformLinks = (json['platformLinks'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      );
    }

    // Parse titleAliases - support both snake_case and camelCase
    List<String>? titleAliases;
    if (json['title_aliases'] != null) {
      titleAliases = (json['title_aliases'] as List<dynamic>)
          .map((e) => e as String)
          .toList();
    } else if (json['titleAliases'] != null) {
      titleAliases = (json['titleAliases'] as List<dynamic>)
          .map((e) => e as String)
          .toList();
    }

    return AnimeDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      titleAlias:
          (json['title_alias'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      coverUrl: (json['cover_url'] ?? json['coverUrl'] ?? '') as String,
      summary: (json['summary'] ?? json['synopsis']) as String?,
      status: AnimeStatus.fromString(json['status'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      platformLinks: platformLinks,
      titleAliases: titleAliases,
      sourceType: json['source_type'] as String?,
      sourceTitle: json['source_title'] as String?,
      platforms:
          (json['platforms'] as List<dynamic>?)
              ?.map((e) => AnimePlatform.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      schedule: json['schedule'] != null
          ? AnimeSchedule.fromJson(json['schedule'] as Map<String, dynamic>)
          : null,
      episodeState: json['episode_state'] != null
          ? AnimeEpisodeState.fromJson(
              json['episode_state'] as Map<String, dynamic>,
            )
          : null,
      aiDigest: json['ai_digest'] != null
          ? AiDigest.fromJson(json['ai_digest'] as Map<String, dynamic>)
          : null,
    );
  }
  final String? sourceType; // manga, novel, original, game
  final String? sourceTitle;
  final List<AnimePlatform> platforms;
  final AnimeSchedule? schedule;
  final AnimeEpisodeState? episodeState;
  final AiDigest? aiDigest;

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'source_type': sourceType,
      'source_title': sourceTitle,
      'platforms': platforms.map((e) => e.toJson()).toList(),
      'schedule': schedule?.toJson(),
      'episode_state': episodeState?.toJson(),
      'ai_digest': aiDigest?.toJson(),
    };
  }

  @override
  AnimeDetail copyWith({
    String? id,
    String? title,
    List<String>? titleAlias,
    String? coverUrl,
    String? summary,
    AnimeStatus? status,
    DateTime? updatedAt,
    Map<String, String>? platformLinks,
    List<String>? titleAliases,
    String? sourceType,
    String? sourceTitle,
    List<AnimePlatform>? platforms,
    AnimeSchedule? schedule,
    AnimeEpisodeState? episodeState,
    AiDigest? aiDigest,
  }) {
    return AnimeDetail(
      id: id ?? this.id,
      title: title ?? this.title,
      titleAlias: titleAlias ?? this.titleAlias,
      coverUrl: coverUrl ?? this.coverUrl,
      summary: summary ?? this.summary,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      platformLinks: platformLinks ?? this.platformLinks,
      titleAliases: titleAliases ?? this.titleAliases,
      sourceType: sourceType ?? this.sourceType,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      platforms: platforms ?? this.platforms,
      schedule: schedule ?? this.schedule,
      episodeState: episodeState ?? this.episodeState,
      aiDigest: aiDigest ?? this.aiDigest,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnimeDetail) return false;
    return super == other &&
        sourceType == other.sourceType &&
        sourceTitle == other.sourceTitle &&
        _listEquals(platforms, other.platforms) &&
        schedule == other.schedule &&
        episodeState == other.episodeState &&
        aiDigest == other.aiDigest;
  }

  @override
  int get hashCode => Object.hash(
    super.hashCode,
    sourceType,
    sourceTitle,
    Object.hashAll(platforms),
    schedule,
    episodeState,
    aiDigest,
  );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// AiDigest model for AI-generated summaries.
class AiDigest {
  const AiDigest({this.summary, this.keyPoints, this.generatedAt});

  factory AiDigest.fromJson(Map<String, dynamic> json) {
    return AiDigest(
      summary: json['summary'] as String?,
      keyPoints: (json['key_points'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'] as String)
          : null,
    );
  }
  final String? summary;
  final List<String>? keyPoints;
  final DateTime? generatedAt;

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'key_points': keyPoints,
      'generated_at': generatedAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AiDigest) return false;
    return summary == other.summary &&
        _listEquals(keyPoints, other.keyPoints) &&
        generatedAt == other.generatedAt;
  }

  @override
  int get hashCode => Object.hash(
    summary,
    keyPoints != null ? Object.hashAll(keyPoints!) : null,
    generatedAt,
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
