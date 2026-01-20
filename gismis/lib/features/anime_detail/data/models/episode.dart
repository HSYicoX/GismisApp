import 'package:flutter/foundation.dart';

/// Episode model representing an anime episode.
@immutable
class Episode {
  const Episode({
    required this.id,
    required this.animeId,
    required this.episodeNumber,
    this.title,
    this.description,
    this.videoUrl,
    this.thumbnailUrl,
    this.duration,
    this.airDate,
    this.createdAt,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'] as String,
      animeId: json['anime_id'] as String,
      episodeNumber: json['episode_number'] as int,
      title: json['title'] as String?,
      description: json['description'] as String?,
      videoUrl: json['video_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      duration: json['duration'] as int?,
      airDate: json['air_date'] != null
          ? DateTime.parse(json['air_date'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  final String id;
  final String animeId;
  final int episodeNumber;
  final String? title;
  final String? description;
  final String? videoUrl;
  final String? thumbnailUrl;
  final int? duration;
  final DateTime? airDate;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'anime_id': animeId,
      'episode_number': episodeNumber,
      'title': title,
      'description': description,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'duration': duration,
      'air_date': airDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Episode copyWith({
    String? id,
    String? animeId,
    int? episodeNumber,
    String? title,
    String? description,
    String? videoUrl,
    String? thumbnailUrl,
    int? duration,
    DateTime? airDate,
    DateTime? createdAt,
  }) {
    return Episode(
      id: id ?? this.id,
      animeId: animeId ?? this.animeId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      airDate: airDate ?? this.airDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Episode) return false;
    return id == other.id && animeId == other.animeId;
  }

  @override
  int get hashCode => Object.hash(id, animeId);
}
