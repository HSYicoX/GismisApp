import 'package:meta/meta.dart';

/// SourceMaterial model representing the original source of an anime.
///
/// This model maps to the `source_materials` table in the database and
/// includes information about novels, manga, games, or original works.
@immutable
class SourceMaterial {
  const SourceMaterial({
    required this.id,
    required this.animeId,
    required this.type,
    this.title,
    this.author,
    this.platform,
    this.platformUrl,
    this.coverUrl,
    this.synopsis,
    this.totalChapters,
    this.latestChapter,
    this.latestChapterTitle,
    this.lastUpdated,
    this.updateStatus,
    this.chapters,
    this.createdAt,
    this.updatedAt,
  });

  factory SourceMaterial.fromJson(Map<String, dynamic> json) {
    return SourceMaterial(
      id: json['id'] as String,
      animeId: json['anime_id'] as String,
      type: SourceMaterialType.fromString(json['type'] as String),
      title: json['title'] as String?,
      author: json['author'] as String?,
      platform: json['platform'] as String?,
      platformUrl: json['platform_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      synopsis: json['synopsis'] as String?,
      totalChapters: json['total_chapters'] as int?,
      latestChapter: json['latest_chapter'] as int?,
      latestChapterTitle: json['latest_chapter_title'] as String?,
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String)
          : null,
      updateStatus: json['update_status'] != null
          ? SourceUpdateStatus.fromString(json['update_status'] as String)
          : null,
      chapters: json['chapters'] != null
          ? (json['chapters'] as List)
                .map((e) => Chapter.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
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

  /// Reference to parent anime
  final String animeId;

  /// Source material type
  final SourceMaterialType type;

  /// Source material title
  final String? title;

  /// Author name
  final String? author;

  /// Platform name (e.g., "起点读书", "番茄小说")
  final String? platform;

  /// Platform URL
  final String? platformUrl;

  /// Cover image URL
  final String? coverUrl;

  /// Synopsis/description
  final String? synopsis;

  /// Total chapter count
  final int? totalChapters;

  /// Latest chapter number
  final int? latestChapter;

  /// Latest chapter title
  final String? latestChapterTitle;

  /// Last update timestamp
  final DateTime? lastUpdated;

  /// Update status
  final SourceUpdateStatus? updateStatus;

  /// Chapters list (from nested query)
  final List<Chapter>? chapters;

  /// Record creation timestamp
  final DateTime? createdAt;

  /// Record update timestamp
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'anime_id': animeId,
      'type': type.value,
      'title': title,
      'author': author,
      'platform': platform,
      'platform_url': platformUrl,
      'cover_url': coverUrl,
      'synopsis': synopsis,
      'total_chapters': totalChapters,
      'latest_chapter': latestChapter,
      'latest_chapter_title': latestChapterTitle,
      'last_updated': lastUpdated?.toIso8601String(),
      'update_status': updateStatus?.value,
      if (chapters != null)
        'chapters': chapters!.map((e) => e.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  SourceMaterial copyWith({
    String? id,
    String? animeId,
    SourceMaterialType? type,
    String? title,
    String? author,
    String? platform,
    String? platformUrl,
    String? coverUrl,
    String? synopsis,
    int? totalChapters,
    int? latestChapter,
    String? latestChapterTitle,
    DateTime? lastUpdated,
    SourceUpdateStatus? updateStatus,
    List<Chapter>? chapters,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SourceMaterial(
      id: id ?? this.id,
      animeId: animeId ?? this.animeId,
      type: type ?? this.type,
      title: title ?? this.title,
      author: author ?? this.author,
      platform: platform ?? this.platform,
      platformUrl: platformUrl ?? this.platformUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      synopsis: synopsis ?? this.synopsis,
      totalChapters: totalChapters ?? this.totalChapters,
      latestChapter: latestChapter ?? this.latestChapter,
      latestChapterTitle: latestChapterTitle ?? this.latestChapterTitle,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updateStatus: updateStatus ?? this.updateStatus,
      chapters: chapters ?? this.chapters,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SourceMaterial) return false;
    return id == other.id &&
        animeId == other.animeId &&
        type == other.type &&
        title == other.title &&
        author == other.author &&
        platform == other.platform &&
        platformUrl == other.platformUrl &&
        coverUrl == other.coverUrl &&
        synopsis == other.synopsis &&
        totalChapters == other.totalChapters &&
        latestChapter == other.latestChapter &&
        latestChapterTitle == other.latestChapterTitle &&
        lastUpdated == other.lastUpdated &&
        updateStatus == other.updateStatus &&
        _listEquals(chapters, other.chapters) &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    animeId,
    type,
    title,
    author,
    platform,
    platformUrl,
    coverUrl,
    synopsis,
    totalChapters,
    latestChapter,
    latestChapterTitle,
    lastUpdated,
    updateStatus,
    chapters != null ? Object.hashAll(chapters!) : null,
    createdAt,
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

/// Chapter model representing a chapter of a source material.
///
/// This model maps to the `chapters` table in the database.
@immutable
class Chapter {
  const Chapter({
    required this.id,
    required this.sourceMaterialId,
    required this.chapterNumber,
    this.title,
    this.wordCount,
    this.publishDate,
    this.isPaid = false,
    this.createdAt,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String,
      sourceMaterialId: json['source_material_id'] as String,
      chapterNumber: json['chapter_number'] as int,
      title: json['title'] as String?,
      wordCount: json['word_count'] as int?,
      publishDate: json['publish_date'] != null
          ? DateTime.parse(json['publish_date'] as String)
          : null,
      isPaid: json['is_paid'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Unique identifier (UUID)
  final String id;

  /// Reference to parent source material
  final String sourceMaterialId;

  /// Chapter number
  final int chapterNumber;

  /// Chapter title
  final String? title;

  /// Word count
  final int? wordCount;

  /// Publish date
  final DateTime? publishDate;

  /// Whether this is a paid chapter
  final bool isPaid;

  /// Record creation timestamp
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_material_id': sourceMaterialId,
      'chapter_number': chapterNumber,
      'title': title,
      'word_count': wordCount,
      'publish_date': publishDate?.toIso8601String(),
      'is_paid': isPaid,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Chapter copyWith({
    String? id,
    String? sourceMaterialId,
    int? chapterNumber,
    String? title,
    int? wordCount,
    DateTime? publishDate,
    bool? isPaid,
    DateTime? createdAt,
  }) {
    return Chapter(
      id: id ?? this.id,
      sourceMaterialId: sourceMaterialId ?? this.sourceMaterialId,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      title: title ?? this.title,
      wordCount: wordCount ?? this.wordCount,
      publishDate: publishDate ?? this.publishDate,
      isPaid: isPaid ?? this.isPaid,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Chapter) return false;
    return id == other.id &&
        sourceMaterialId == other.sourceMaterialId &&
        chapterNumber == other.chapterNumber &&
        title == other.title &&
        wordCount == other.wordCount &&
        publishDate == other.publishDate &&
        isPaid == other.isPaid &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceMaterialId,
    chapterNumber,
    title,
    wordCount,
    publishDate,
    isPaid,
    createdAt,
  );
}

/// Source material type enum.
enum SourceMaterialType {
  novel('novel'),
  manga('manga'),
  game('game'),
  original('original');

  const SourceMaterialType(this.value);

  final String value;

  static SourceMaterialType fromString(String value) {
    return SourceMaterialType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SourceMaterialType.original,
    );
  }
}

/// Source update status enum.
enum SourceUpdateStatus {
  ongoing('ongoing'),
  completed('completed'),
  hiatus('hiatus');

  const SourceUpdateStatus(this.value);

  final String value;

  static SourceUpdateStatus fromString(String value) {
    return SourceUpdateStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SourceUpdateStatus.ongoing,
    );
  }
}
