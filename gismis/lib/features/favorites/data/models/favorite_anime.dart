import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../../shared/models/anime.dart';

part 'favorite_anime.g.dart';

/// FavoriteAnime model representing a user's favorite anime with sync metadata.
///
/// This model is designed for local-first storage with cloud sync support.
/// It stores the anime data along with metadata for sync operations.
///
/// Requirements: 5.1 - Local-first favorites storage
@immutable
@HiveType(typeId: 10)
class FavoriteAnime {
  const FavoriteAnime({
    required this.animeId,
    required this.title,
    required this.coverUrl,
    required this.addedAt,
    this.status = AnimeStatus.ongoing,
    this.syncedAt,
    this.customOrder,
  });

  /// Creates a FavoriteAnime from an Anime model.
  factory FavoriteAnime.fromAnime(Anime anime, {int? customOrder}) {
    return FavoriteAnime(
      animeId: anime.id,
      title: anime.title,
      coverUrl: anime.coverUrl,
      status: anime.status,
      addedAt: DateTime.now(),
      customOrder: customOrder,
    );
  }

  /// Creates a FavoriteAnime from JSON (server response).
  factory FavoriteAnime.fromJson(Map<String, dynamic> json) {
    return FavoriteAnime(
      animeId: json['anime_id'] as String,
      title: json['title'] as String,
      coverUrl: json['cover_url'] as String,
      status: json['status'] != null
          ? AnimeStatus.fromString(json['status'] as String)
          : AnimeStatus.ongoing,
      addedAt: json['added_at'] != null
          ? DateTime.parse(json['added_at'] as String)
          : DateTime.now(),
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
      customOrder: json['custom_order'] as int?,
    );
  }

  /// The unique identifier of the anime.
  @HiveField(0)
  final String animeId;

  /// The title of the anime.
  @HiveField(1)
  final String title;

  /// The cover image URL.
  @HiveField(2)
  final String coverUrl;

  /// The anime status (ongoing, completed, etc.).
  @HiveField(3)
  final AnimeStatus status;

  /// When the anime was added to favorites.
  @HiveField(4)
  final DateTime addedAt;

  /// When the favorite was last synced with the server.
  /// Null if never synced.
  @HiveField(5)
  final DateTime? syncedAt;

  /// Custom order position for user-defined sorting.
  @HiveField(6)
  final int? customOrder;

  /// Whether this favorite has been synced with the server.
  bool get isSynced => syncedAt != null;

  /// Converts to JSON for API requests.
  Map<String, dynamic> toJson() {
    return {
      'anime_id': animeId,
      'title': title,
      'cover_url': coverUrl,
      'status': status.value,
      'added_at': addedAt.toIso8601String(),
      if (syncedAt != null) 'synced_at': syncedAt!.toIso8601String(),
      if (customOrder != null) 'custom_order': customOrder,
    };
  }

  /// Creates a copy with updated fields.
  FavoriteAnime copyWith({
    String? animeId,
    String? title,
    String? coverUrl,
    AnimeStatus? status,
    DateTime? addedAt,
    DateTime? syncedAt,
    int? customOrder,
  }) {
    return FavoriteAnime(
      animeId: animeId ?? this.animeId,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      status: status ?? this.status,
      addedAt: addedAt ?? this.addedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      customOrder: customOrder ?? this.customOrder,
    );
  }

  /// Marks this favorite as synced with the current timestamp.
  FavoriteAnime markSynced() {
    return copyWith(syncedAt: DateTime.now());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FavoriteAnime) return false;
    return animeId == other.animeId &&
        title == other.title &&
        coverUrl == other.coverUrl &&
        status == other.status &&
        addedAt == other.addedAt &&
        syncedAt == other.syncedAt &&
        customOrder == other.customOrder;
  }

  @override
  int get hashCode => Object.hash(
    animeId,
    title,
    coverUrl,
    status,
    addedAt,
    syncedAt,
    customOrder,
  );

  @override
  String toString() {
    return 'FavoriteAnime(animeId: $animeId, title: $title, addedAt: $addedAt, '
        'isSynced: $isSynced)';
  }
}

/// Hive TypeAdapter for AnimeStatus enum.
class AnimeStatusAdapter extends TypeAdapter<AnimeStatus> {
  @override
  final int typeId = 11;

  @override
  AnimeStatus read(BinaryReader reader) {
    final value = reader.readString();
    return AnimeStatus.fromString(value);
  }

  @override
  void write(BinaryWriter writer, AnimeStatus obj) {
    writer.writeString(obj.value);
  }
}
