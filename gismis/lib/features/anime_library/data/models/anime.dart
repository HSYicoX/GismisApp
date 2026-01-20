import 'package:meta/meta.dart';

/// Anime model representing anime information from Supabase.
///
/// This model maps to the `anime` table in the database and includes
/// all metadata fields for anime series.
@immutable
class AnimeLibraryItem {
  const AnimeLibraryItem({
    required this.id,
    required this.title,
    this.titleJa,
    this.synopsis,
    this.coverUrl,
    this.bannerUrl,
    this.genres = const [],
    this.rating,
    required this.status,
    this.startDate,
    this.endDate,
    this.seasonCount,
    this.currentSeason,
    this.platformLinks = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory AnimeLibraryItem.fromJson(Map<String, dynamic> json) {
    // Parse platform links if available from nested query
    Map<String, String> links = {};
    if (json['anime_platform_links'] != null) {
      links = Map.fromEntries(
        (json['anime_platform_links'] as List).map(
          (e) => MapEntry(e['platform'] as String, e['url'] as String),
        ),
      );
    }

    return AnimeLibraryItem(
      id: json['id'] as String,
      title: json['title'] as String,
      titleJa: json['title_ja'] as String?,
      synopsis: json['synopsis'] as String?,
      coverUrl: json['cover_url'] as String?,
      bannerUrl: json['banner_url'] as String?,
      genres:
          (json['genres'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      rating: (json['rating'] as num?)?.toDouble(),
      status: AnimeLibraryStatus.fromString(json['status'] as String),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      seasonCount: json['season_count'] as int?,
      currentSeason: json['current_season'] as int?,
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

  /// Primary title
  final String title;

  /// Japanese title
  final String? titleJa;

  /// Synopsis/description
  final String? synopsis;

  /// Cover image URL
  final String? coverUrl;

  /// Banner image URL
  final String? bannerUrl;

  /// Genre tags
  final List<String> genres;

  /// Rating (0.0 - 10.0)
  final double? rating;

  /// Airing status
  final AnimeLibraryStatus status;

  /// Start date of the anime
  final DateTime? startDate;

  /// End date of the anime
  final DateTime? endDate;

  /// Total number of seasons
  final int? seasonCount;

  /// Current season number
  final int? currentSeason;

  /// Platform links (platform -> url)
  final Map<String, String> platformLinks;

  /// Record creation timestamp
  final DateTime? createdAt;

  /// Record update timestamp
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'title_ja': titleJa,
      'synopsis': synopsis,
      'cover_url': coverUrl,
      'banner_url': bannerUrl,
      'genres': genres,
      'rating': rating,
      'status': status.value,
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'season_count': seasonCount,
      'current_season': currentSeason,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  AnimeLibraryItem copyWith({
    String? id,
    String? title,
    String? titleJa,
    String? synopsis,
    String? coverUrl,
    String? bannerUrl,
    List<String>? genres,
    double? rating,
    AnimeLibraryStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    int? seasonCount,
    int? currentSeason,
    Map<String, String>? platformLinks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AnimeLibraryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      titleJa: titleJa ?? this.titleJa,
      synopsis: synopsis ?? this.synopsis,
      coverUrl: coverUrl ?? this.coverUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      genres: genres ?? this.genres,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      seasonCount: seasonCount ?? this.seasonCount,
      currentSeason: currentSeason ?? this.currentSeason,
      platformLinks: platformLinks ?? this.platformLinks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnimeLibraryItem) return false;
    return id == other.id &&
        title == other.title &&
        titleJa == other.titleJa &&
        synopsis == other.synopsis &&
        coverUrl == other.coverUrl &&
        bannerUrl == other.bannerUrl &&
        _listEquals(genres, other.genres) &&
        rating == other.rating &&
        status == other.status &&
        startDate == other.startDate &&
        endDate == other.endDate &&
        seasonCount == other.seasonCount &&
        currentSeason == other.currentSeason &&
        _mapEquals(platformLinks, other.platformLinks) &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    titleJa,
    synopsis,
    coverUrl,
    bannerUrl,
    Object.hashAll(genres),
    rating,
    status,
    startDate,
    endDate,
    seasonCount,
    currentSeason,
    Object.hashAll(platformLinks.entries),
    createdAt,
    updatedAt,
  );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Anime airing status enum.
enum AnimeLibraryStatus {
  airing('airing'),
  completed('completed'),
  upcoming('upcoming');

  const AnimeLibraryStatus(this.value);

  final String value;

  static AnimeLibraryStatus fromString(String value) {
    return AnimeLibraryStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AnimeLibraryStatus.upcoming,
    );
  }
}
