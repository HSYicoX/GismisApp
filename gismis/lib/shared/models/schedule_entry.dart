import 'anime.dart';
import 'user_anime_follow.dart';

/// ScheduleEntry model representing an anime entry in the weekly schedule.
class ScheduleEntry {
  const ScheduleEntry({
    required this.anime,
    required this.latestEpisode,
    this.userFollow,
  });

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) {
    return ScheduleEntry(
      anime: Anime.fromJson(json['anime'] as Map<String, dynamic>),
      userFollow: json['user_follow'] != null
          ? UserAnimeFollow.fromJson(
              json['user_follow'] as Map<String, dynamic>,
            )
          : null,
      latestEpisode: json['latest_episode'] as int,
    );
  }
  final Anime anime;
  final UserAnimeFollow? userFollow;
  final int latestEpisode;

  Map<String, dynamic> toJson() {
    return {
      'anime': anime.toJson(),
      'user_follow': userFollow?.toJson(),
      'latest_episode': latestEpisode,
    };
  }

  ScheduleEntry copyWith({
    Anime? anime,
    UserAnimeFollow? userFollow,
    int? latestEpisode,
  }) {
    return ScheduleEntry(
      anime: anime ?? this.anime,
      userFollow: userFollow ?? this.userFollow,
      latestEpisode: latestEpisode ?? this.latestEpisode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ScheduleEntry) return false;
    return anime == other.anime &&
        userFollow == other.userFollow &&
        latestEpisode == other.latestEpisode;
  }

  @override
  int get hashCode => Object.hash(anime, userFollow, latestEpisode);
}
