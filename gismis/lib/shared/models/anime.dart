/// Anime model representing basic anime information.
class Anime {
  const Anime({
    required this.id,
    required this.title,
    required this.titleAlias,
    required this.coverUrl,
    required this.status,
    required this.updatedAt,
    this.summary,
    this.platformLinks,
    this.titleAliases,
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    // Parse platformLinks from JSON (can be null or a map)
    Map<String, String>? platformLinks;
    if (json['platform_links'] != null) {
      platformLinks = (json['platform_links'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      );
    } else if (json['platformLinks'] != null) {
      // Also support camelCase from Edge Functions
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

    return Anime(
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
    );
  }
  final String id;
  final String title;
  final List<String> titleAlias;
  final String coverUrl;
  final String? summary;
  final AnimeStatus status;
  final DateTime updatedAt;

  /// Platform-specific play URLs mapping { platform: playUrl }
  /// e.g., { 'bilibili': 'https://...', 'tmdb': 'https://...' }
  final Map<String, String>? platformLinks;

  /// Alternative titles (Japanese, English, etc.) from aggregated sources
  final List<String>? titleAliases;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'title_alias': titleAlias,
      'cover_url': coverUrl,
      'summary': summary,
      'status': status.value,
      'updated_at': updatedAt.toIso8601String(),
      if (platformLinks != null) 'platform_links': platformLinks,
      if (titleAliases != null) 'title_aliases': titleAliases,
    };
  }

  Anime copyWith({
    String? id,
    String? title,
    List<String>? titleAlias,
    String? coverUrl,
    String? summary,
    AnimeStatus? status,
    DateTime? updatedAt,
    Map<String, String>? platformLinks,
    List<String>? titleAliases,
  }) {
    return Anime(
      id: id ?? this.id,
      title: title ?? this.title,
      titleAlias: titleAlias ?? this.titleAlias,
      coverUrl: coverUrl ?? this.coverUrl,
      summary: summary ?? this.summary,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      platformLinks: platformLinks ?? this.platformLinks,
      titleAliases: titleAliases ?? this.titleAliases,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Anime) return false;
    return id == other.id &&
        title == other.title &&
        _listEquals(titleAlias, other.titleAlias) &&
        coverUrl == other.coverUrl &&
        summary == other.summary &&
        status == other.status &&
        updatedAt == other.updatedAt &&
        _mapEquals(platformLinks, other.platformLinks) &&
        _listEquals(titleAliases ?? [], other.titleAliases ?? []);
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    Object.hashAll(titleAlias),
    coverUrl,
    summary,
    status,
    updatedAt,
    platformLinks != null ? Object.hashAll(platformLinks!.entries) : null,
    titleAliases != null ? Object.hashAll(titleAliases!) : null,
  );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

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

/// Anime status enum.
enum AnimeStatus {
  ongoing('ongoing'),
  completed('completed'),
  upcoming('upcoming'),
  hiatus('hiatus');

  final String value;
  const AnimeStatus(this.value);

  static AnimeStatus fromString(String value) {
    return AnimeStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AnimeStatus.ongoing,
    );
  }
}
