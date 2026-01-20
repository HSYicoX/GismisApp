import 'dart:convert';

import 'package:hive/hive.dart';

import '../../shared/models/anime.dart';
import '../../shared/models/anime_detail.dart';
import '../../shared/models/user_anime_follow.dart';

/// CacheService provides local caching functionality using Hive.
///
/// This service stores anime data locally for offline access and
/// cache-first display strategy. Data is stored as JSON strings
/// to avoid the complexity of Hive type adapters.
class CacheService {
  static const String _animeListBoxName = 'anime_list_cache';
  static const String _animeDetailBoxName = 'anime_detail_cache';
  static const String _userFollowBoxName = 'user_follow_cache';
  static const String _metadataBoxName = 'cache_metadata';

  static const String _animeListKey = 'anime_list';
  static const String _lastUpdatedPrefix = 'last_updated_';

  Box<String>? _animeListBox;
  Box<String>? _animeDetailBox;
  Box<String>? _userFollowBox;
  Box<String>? _metadataBox;

  bool _isInitialized = false;

  /// Initialize Hive and open all cache boxes.
  ///
  /// For Flutter apps, call this after Hive.initFlutter() in main.dart.
  /// For tests, call Hive.init(path) before calling this method.
  Future<void> initialize() async {
    if (_isInitialized) return;

    _animeListBox = await Hive.openBox<String>(_animeListBoxName);
    _animeDetailBox = await Hive.openBox<String>(_animeDetailBoxName);
    _userFollowBox = await Hive.openBox<String>(_userFollowBoxName);
    _metadataBox = await Hive.openBox<String>(_metadataBoxName);

    _isInitialized = true;
  }

  /// Ensure the service is initialized before use.
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'CacheService not initialized. Call initialize() first.',
      );
    }
  }

  // ============================================================
  // Anime List Caching
  // ============================================================

  /// Cache a list of anime for offline access.
  Future<void> cacheAnimeList(List<Anime> animes) async {
    _ensureInitialized();

    final jsonList = animes.map((anime) => anime.toJson()).toList();
    final jsonString = jsonEncode(jsonList);

    await _animeListBox!.put(_animeListKey, jsonString);
    await _updateTimestamp(_animeListKey);
  }

  /// Retrieve cached anime list.
  /// Returns null if no cached data exists.
  Future<List<Anime>?> getCachedAnimeList() async {
    _ensureInitialized();

    final jsonString = _animeListBox!.get(_animeListKey);
    if (jsonString == null) return null;

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => Anime.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If parsing fails, return null and let caller fetch fresh data
      return null;
    }
  }

  /// Get the timestamp when anime list was last cached.
  Future<DateTime?> getAnimeListCacheTime() async {
    return _getTimestamp(_animeListKey);
  }

  // ============================================================
  // Anime Detail Caching
  // ============================================================

  /// Cache anime detail for a specific anime ID.
  Future<void> cacheAnimeDetail(String animeId, AnimeDetail detail) async {
    _ensureInitialized();

    final jsonString = jsonEncode(detail.toJson());
    await _animeDetailBox!.put(animeId, jsonString);
    await _updateTimestamp('detail_$animeId');
  }

  /// Retrieve cached anime detail by ID.
  /// Returns null if no cached data exists.
  Future<AnimeDetail?> getCachedAnimeDetail(String animeId) async {
    _ensureInitialized();

    final jsonString = _animeDetailBox!.get(animeId);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return AnimeDetail.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Get the timestamp when a specific anime detail was last cached.
  Future<DateTime?> getAnimeDetailCacheTime(String animeId) async {
    return _getTimestamp('detail_$animeId');
  }

  /// Remove cached anime detail for a specific ID.
  Future<void> removeCachedAnimeDetail(String animeId) async {
    _ensureInitialized();

    await _animeDetailBox!.delete(animeId);
    await _metadataBox!.delete('$_lastUpdatedPrefix detail_$animeId');
  }

  // ============================================================
  // User Follow Caching
  // ============================================================

  /// Cache user's followed anime list.
  Future<void> cacheUserFollows(List<UserAnimeFollow> follows) async {
    _ensureInitialized();

    final jsonList = follows.map((follow) => follow.toJson()).toList();
    final jsonString = jsonEncode(jsonList);

    await _userFollowBox!.put('follows', jsonString);
    await _updateTimestamp('user_follows');
  }

  /// Retrieve cached user follows.
  /// Returns null if no cached data exists.
  Future<List<UserAnimeFollow>?> getCachedUserFollows() async {
    _ensureInitialized();

    final jsonString = _userFollowBox!.get('follows');
    if (jsonString == null) return null;

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => UserAnimeFollow.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return null;
    }
  }

  /// Cache a single user follow entry.
  Future<void> cacheUserFollow(UserAnimeFollow follow) async {
    _ensureInitialized();

    final jsonString = jsonEncode(follow.toJson());
    await _userFollowBox!.put('follow_${follow.animeId}', jsonString);
  }

  /// Get cached follow status for a specific anime.
  Future<UserAnimeFollow?> getCachedUserFollow(String animeId) async {
    _ensureInitialized();

    final jsonString = _userFollowBox!.get('follow_$animeId');
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserAnimeFollow.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Remove cached follow for a specific anime.
  Future<void> removeCachedUserFollow(String animeId) async {
    _ensureInitialized();

    await _userFollowBox!.delete('follow_$animeId');
  }

  // ============================================================
  // Cache Management
  // ============================================================

  /// Clear all cached data.
  Future<void> clearCache() async {
    _ensureInitialized();

    await _animeListBox!.clear();
    await _animeDetailBox!.clear();
    await _userFollowBox!.clear();
    await _metadataBox!.clear();
  }

  /// Clear only anime-related caches (not user data).
  Future<void> clearAnimeCache() async {
    _ensureInitialized();

    await _animeListBox!.clear();
    await _animeDetailBox!.clear();
  }

  /// Check if cache is stale (older than specified duration).
  Future<bool> isCacheStale(String key, Duration maxAge) async {
    final timestamp = await _getTimestamp(key);
    if (timestamp == null) return true;

    return DateTime.now().difference(timestamp) > maxAge;
  }

  /// Check if anime list cache exists and is not empty.
  Future<bool> hasAnimeListCache() async {
    _ensureInitialized();
    return _animeListBox!.containsKey(_animeListKey);
  }

  /// Check if anime detail cache exists for a specific ID.
  Future<bool> hasAnimeDetailCache(String animeId) async {
    _ensureInitialized();
    return _animeDetailBox!.containsKey(animeId);
  }

  // ============================================================
  // Private Helpers
  // ============================================================

  Future<void> _updateTimestamp(String key) async {
    await _metadataBox!.put(
      '$_lastUpdatedPrefix$key',
      DateTime.now().toIso8601String(),
    );
  }

  Future<DateTime?> _getTimestamp(String key) async {
    _ensureInitialized();

    final timestampStr = _metadataBox!.get('$_lastUpdatedPrefix$key');
    if (timestampStr == null) return null;

    try {
      return DateTime.parse(timestampStr);
    } catch (e) {
      return null;
    }
  }

  /// Close all Hive boxes. Call this when the app is closing.
  Future<void> dispose() async {
    await _animeListBox?.close();
    await _animeDetailBox?.close();
    await _userFollowBox?.close();
    await _metadataBox?.close();
    _isInitialized = false;
  }
}
