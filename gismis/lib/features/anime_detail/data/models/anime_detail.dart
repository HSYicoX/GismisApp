import 'package:flutter/foundation.dart';

/// AnimeDetail model with full anime information.
@immutable
class AnimeDetail {
  const AnimeDetail({
    required this.id,
    required this.title,
    this.coverUrl,
    this.description,
    this.status,
    this.totalEpisodes,
    this.currentEpisode,
    this.createdAt,
    this.updatedAt,
    this.genres,
    this.year,
    this.rating,
    this.studio,
    this.director,
    this.voiceActors,
  });

  factory AnimeDetail.fromJson(Map<String, dynamic> json) {
    return AnimeDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      coverUrl: json['cover_url'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String?,
      totalEpisodes: json['total_episodes'] as int?,
      currentEpisode: json['current_episode'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      genres: (json['genres'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      year: json['year'] as int?,
      rating: (json['rating'] as num?)?.toDouble(),
      studio: json['studio'] as String?,
      director: json['director'] as String?,
      voiceActors: (json['voice_actors'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  final String id;
  final String title;
  final String? coverUrl;
  final String? description;
  final String? status;
  final int? totalEpisodes;
  final int? currentEpisode;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String>? genres;
  final int? year;
  final double? rating;
  final String? studio;
  final String? director;
  final List<String>? voiceActors;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'cover_url': coverUrl,
      'description': description,
      'status': status,
      'total_episodes': totalEpisodes,
      'current_episode': currentEpisode,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'genres': genres,
      'year': year,
      'rating': rating,
      'studio': studio,
      'director': director,
      'voice_actors': voiceActors,
    };
  }

  AnimeDetail copyWith({
    String? id,
    String? title,
    String? coverUrl,
    String? description,
    String? status,
    int? totalEpisodes,
    int? currentEpisode,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? genres,
    int? year,
    double? rating,
    String? studio,
    String? director,
    List<String>? voiceActors,
  }) {
    return AnimeDetail(
      id: id ?? this.id,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      status: status ?? this.status,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      genres: genres ?? this.genres,
      year: year ?? this.year,
      rating: rating ?? this.rating,
      studio: studio ?? this.studio,
      director: director ?? this.director,
      voiceActors: voiceActors ?? this.voiceActors,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnimeDetail) return false;
    return id == other.id && title == other.title;
  }

  @override
  int get hashCode => Object.hash(id, title);
}
