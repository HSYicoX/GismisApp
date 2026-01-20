/// UserAnimeFollow model representing a user's follow relationship with an anime.
class UserAnimeFollow {
  const UserAnimeFollow({
    required this.id,
    required this.animeId,
    required this.progressEpisode,
    required this.isFavorite,
    this.followWeekdayOverride,
    this.notes,
  });

  factory UserAnimeFollow.fromJson(Map<String, dynamic> json) {
    return UserAnimeFollow(
      id: json['id'] as String,
      animeId: json['anime_id'] as String,
      progressEpisode: json['progress_episode'] as int,
      followWeekdayOverride: json['follow_weekday_override'] as int?,
      notes: json['notes'] as String?,
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }
  final String id;
  final String animeId;
  final int progressEpisode;
  final int? followWeekdayOverride;
  final String? notes;
  final bool isFavorite;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'anime_id': animeId,
      'progress_episode': progressEpisode,
      'follow_weekday_override': followWeekdayOverride,
      'notes': notes,
      'is_favorite': isFavorite,
    };
  }

  UserAnimeFollow copyWith({
    String? id,
    String? animeId,
    int? progressEpisode,
    int? followWeekdayOverride,
    String? notes,
    bool? isFavorite,
  }) {
    return UserAnimeFollow(
      id: id ?? this.id,
      animeId: animeId ?? this.animeId,
      progressEpisode: progressEpisode ?? this.progressEpisode,
      followWeekdayOverride:
          followWeekdayOverride ?? this.followWeekdayOverride,
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UserAnimeFollow) return false;
    return id == other.id &&
        animeId == other.animeId &&
        progressEpisode == other.progressEpisode &&
        followWeekdayOverride == other.followWeekdayOverride &&
        notes == other.notes &&
        isFavorite == other.isFavorite;
  }

  @override
  int get hashCode => Object.hash(
    id,
    animeId,
    progressEpisode,
    followWeekdayOverride,
    notes,
    isFavorite,
  );
}
