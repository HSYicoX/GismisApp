/// AnimeEpisodeState model representing the latest episode information.
class AnimeEpisodeState {
  const AnimeEpisodeState({
    required this.latestEpisode,
    required this.lastCheckedAt,
    this.latestTitle,
    this.latestBrief,
  });

  factory AnimeEpisodeState.fromJson(Map<String, dynamic> json) {
    return AnimeEpisodeState(
      latestEpisode: json['latest_episode'] as int,
      latestTitle: json['latest_title'] as String?,
      latestBrief: json['latest_brief'] as String?,
      lastCheckedAt: DateTime.parse(json['last_checked_at'] as String),
    );
  }
  final int latestEpisode;
  final String? latestTitle;
  final String? latestBrief;
  final DateTime lastCheckedAt;

  Map<String, dynamic> toJson() {
    return {
      'latest_episode': latestEpisode,
      'latest_title': latestTitle,
      'latest_brief': latestBrief,
      'last_checked_at': lastCheckedAt.toIso8601String(),
    };
  }

  AnimeEpisodeState copyWith({
    int? latestEpisode,
    String? latestTitle,
    String? latestBrief,
    DateTime? lastCheckedAt,
  }) {
    return AnimeEpisodeState(
      latestEpisode: latestEpisode ?? this.latestEpisode,
      latestTitle: latestTitle ?? this.latestTitle,
      latestBrief: latestBrief ?? this.latestBrief,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnimeEpisodeState) return false;
    return latestEpisode == other.latestEpisode &&
        latestTitle == other.latestTitle &&
        latestBrief == other.latestBrief &&
        lastCheckedAt == other.lastCheckedAt;
  }

  @override
  int get hashCode =>
      Object.hash(latestEpisode, latestTitle, latestBrief, lastCheckedAt);
}
