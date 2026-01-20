/// Supabase Watch History Repository for user watch progress operations.
///
/// Implements local caching with server sync strategy:
/// - Reads return cached data immediately, then refresh in background
/// - Progress updates are sent to server, then cached locally
/// - Supports pagination for large watch histories
///
/// Requirements: 5.1
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/supabase/paginated_result.dart';
import '../../../core/supabase/supabase_client.dart';
import 'models/watch_record.dart';

/// Repository for managing user watch history with local cache + server sync.
///
/// Access pattern:
/// - Read: Local cache first, background refresh from server via Edge Functions
/// - Write: Server first via Edge Functions, then update local cache
///
/// Requirements: 5.1
class WatchHistoryRepository {
  /// Creates a new watch history repository.
  WatchHistoryRepository({
    required SupabaseClient supabaseClient,
    required SecureStorageService tokenStorage,
    String boxName = 'watch_history',
  }) : _supabaseClient = supabaseClient,
       _tokenStorage = tokenStorage,
       _boxName = boxName;

  final SupabaseClient _supabaseClient;
  final SecureStorageService _tokenStorage;
  final String _boxName;

  Box<String>? _box;
  bool _isInitialized = false;

  static const _historyListKey = 'history_list';
  static const _lastFetchKey = 'last_fetch_time';
  static const _cacheDuration = Duration(minutes: 15);

  /// Initialize the repository storage.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _box = await Hive.openBox<String>(_boxName);
    _isInitialized = true;
  }

  void _ensureInitialized() {
    if (!_isInitialized || _box == null) {
      throw StateError(
        'WatchHistoryRepository not initialized. Call initialize() first.',
      );
    }
  }

  // ============================================================
  // Read Operations (Cache First + Background Refresh)
  // ============================================================

  /// Gets the user's watch history with cache-first strategy.
  ///
  /// Returns cached history immediately if available, then triggers
  /// a background refresh from the server. If no cache exists,
  /// fetches from server directly.
  ///
  /// Parameters:
  /// - [page]: Page number (1-based)
  /// - [pageSize]: Number of items per page
  /// - [completedOnly]: Filter to only completed episodes
  /// - [animeId]: Filter to specific anime
  /// - [forceRefresh]: Skip cache and fetch from server
  ///
  /// Requirements: 5.1 - Watch history retrieval
  Future<PaginatedResult<WatchRecord>> getWatchHistory({
    int page = 1,
    int pageSize = 20,
    bool completedOnly = false,
    String? animeId,
    bool forceRefresh = false,
  }) async {
    _ensureInitialized();

    // Build cache key based on query parameters
    final cacheKey = _buildCacheKey(
      page: page,
      pageSize: pageSize,
      completedOnly: completedOnly,
      animeId: animeId,
    );

    // Check if we have cached data
    if (!forceRefresh) {
      final cached = _getCachedHistory(cacheKey);
      if (cached != null && !_isCacheStale(cacheKey)) {
        // Return cached data, trigger background refresh if stale
        _refreshHistoryInBackground(
          page: page,
          pageSize: pageSize,
          completedOnly: completedOnly,
          animeId: animeId,
          cacheKey: cacheKey,
        );
        return cached;
      }
    }

    // No cache or force refresh - fetch from server
    return _fetchHistoryFromServer(
      page: page,
      pageSize: pageSize,
      completedOnly: completedOnly,
      animeId: animeId,
      cacheKey: cacheKey,
    );
  }

  /// Gets a single watch record by episode ID from cache.
  WatchRecord? getWatchRecordForEpisode(String episodeId) {
    _ensureInitialized();
    final jsonString = _box!.get('episode_$episodeId');
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return WatchRecord.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  /// Gets cached history without triggering refresh.
  PaginatedResult<WatchRecord>? _getCachedHistory(String cacheKey) {
    _ensureInitialized();
    final jsonString = _box!.get(cacheKey);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final items = (json['items'] as List<dynamic>)
          .map((e) => WatchRecord.fromJson(e as Map<String, dynamic>))
          .toList();

      return PaginatedResult<WatchRecord>(
        items: items,
        total: json['total'] as int?,
        offset: json['offset'] as int,
        limit: json['limit'] as int?,
        hasMore: json['hasMore'] as bool,
      );
    } on FormatException {
      debugPrint('WatchHistoryRepository: Malformed cached history');
      return null;
    }
  }

  /// Checks if the cache is stale.
  bool _isCacheStale(String cacheKey) {
    final lastFetchStr = _box!.get('${_lastFetchKey}_$cacheKey');
    if (lastFetchStr == null) return true;

    try {
      final lastFetch = DateTime.parse(lastFetchStr);
      return DateTime.now().difference(lastFetch) > _cacheDuration;
    } on FormatException {
      return true;
    }
  }

  /// Refreshes history in background (fire and forget).
  void _refreshHistoryInBackground({
    required int page,
    required int pageSize,
    required bool completedOnly,
    required String cacheKey,
    String? animeId,
  }) {
    Future.microtask(() async {
      try {
        await _fetchHistoryFromServer(
          page: page,
          pageSize: pageSize,
          completedOnly: completedOnly,
          animeId: animeId,
          cacheKey: cacheKey,
        );
      } on Exception catch (e) {
        debugPrint('WatchHistoryRepository: Background refresh failed: $e');
      }
    });
  }

  /// Fetches history from server via Edge Function.
  ///
  /// Requirements: 5.1 - Get watch history via Edge Function
  Future<PaginatedResult<WatchRecord>> _fetchHistoryFromServer({
    required int page,
    required int pageSize,
    required bool completedOnly,
    required String cacheKey,
    String? animeId,
  }) async {
    final token = await _tokenStorage.getAccessToken();
    if (token == null) {
      throw const ApiException(
        type: ApiErrorType.unauthorized,
        message: 'Not authenticated',
      );
    }

    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        if (completedOnly) 'completed': 'true',
        if (animeId != null) 'anime_id': animeId,
      };

      final response = await _supabaseClient
          .callFunctionGet<Map<String, dynamic>>(
            'get-watch-history',
            accessToken: token,
            queryParameters: queryParams,
          );

      if (response.data == null) {
        return PaginatedResult<WatchRecord>(
          items: [],
          total: 0,
          offset: (page - 1) * pageSize,
          limit: pageSize,
          hasMore: false,
        );
      }

      final data = response.data!;
      final items = (data['data'] as List<dynamic>? ?? [])
          .map((e) => WatchRecord.fromJson(e as Map<String, dynamic>))
          .toList();

      final pagination = data['pagination'] as Map<String, dynamic>?;
      final total = pagination?['total'] as int? ?? items.length;
      final hasMore = pagination?['hasMore'] as bool? ?? false;

      final result = PaginatedResult<WatchRecord>(
        items: items,
        total: total,
        offset: (page - 1) * pageSize,
        limit: pageSize,
        hasMore: hasMore,
      );

      // Cache the result
      await _cacheHistory(cacheKey, result);

      // Also cache individual records by episode ID for quick lookup
      for (final record in items) {
        await _cacheWatchRecord(record);
      }

      return result;
    } on ApiException {
      rethrow;
    }
  }

  /// Caches the history result.
  Future<void> _cacheHistory(
    String cacheKey,
    PaginatedResult<WatchRecord> result,
  ) async {
    _ensureInitialized();
    final json = {
      'items': result.items.map((e) => e.toJson()).toList(),
      'total': result.total,
      'offset': result.offset,
      'limit': result.limit,
      'hasMore': result.hasMore,
    };
    await _box!.put(cacheKey, jsonEncode(json));
    await _box!.put(
      '${_lastFetchKey}_$cacheKey',
      DateTime.now().toIso8601String(),
    );
  }

  /// Caches a single watch record by episode ID.
  Future<void> _cacheWatchRecord(WatchRecord record) async {
    _ensureInitialized();
    final jsonString = jsonEncode(record.toJson());
    await _box!.put('episode_${record.episodeId}', jsonString);
  }

  // ============================================================
  // Write Operations (Server First + Cache Update)
  // ============================================================

  /// Updates watch progress for an episode.
  ///
  /// Sends update to server via Edge Function, then updates local cache.
  /// The server handles upsert logic (create or update).
  ///
  /// Parameters:
  /// - [episodeId]: The episode being watched
  /// - [progress]: Current progress in seconds
  /// - [duration]: Total duration in seconds (optional)
  /// - [completed]: Whether the episode is completed (optional, auto-calculated if not provided)
  ///
  /// Requirements: 5.1 - Update watch progress via Edge Function
  Future<WatchRecord> updateProgress({
    required String episodeId,
    required int progress,
    int? duration,
    bool? completed,
  }) async {
    _ensureInitialized();

    final token = await _tokenStorage.getAccessToken();
    if (token == null) {
      throw const ApiException(
        type: ApiErrorType.unauthorized,
        message: 'Not authenticated',
      );
    }

    final request = UpdateProgressRequest(
      episodeId: episodeId,
      progress: progress,
      duration: duration,
      completed: completed,
    );

    try {
      final response = await _supabaseClient.callFunction<Map<String, dynamic>>(
        'update-watch-progress',
        accessToken: token,
        data: request.toJson(),
      );

      if (response.data == null) {
        throw const ApiException(
          type: ApiErrorType.serverError,
          message: 'Empty response from server',
        );
      }

      // Parse the response - it returns the updated record
      final data =
          response.data!['data'] as Map<String, dynamic>? ?? response.data!;

      // Create a minimal WatchRecord from the response
      final record = WatchRecord(
        id: data['id'] as String,
        episodeId: data['episode_id'] as String,
        progress: data['progress'] as int,
        duration: data['duration'] as int?,
        watchedAt: data['watched_at'] != null
            ? DateTime.parse(data['watched_at'] as String)
            : DateTime.now(),
        completed: data['completed'] as bool? ?? false,
      );

      // Update local cache
      await _cacheWatchRecord(record);

      // Invalidate history list cache (will be refreshed on next read)
      await _invalidateHistoryCache();

      return record;
    } on ApiException {
      rethrow;
    }
  }

  /// Marks an episode as completed.
  ///
  /// Convenience method for marking an episode as fully watched.
  Future<WatchRecord> markAsCompleted({
    required String episodeId,
    required int duration,
  }) async {
    return updateProgress(
      episodeId: episodeId,
      progress: duration,
      duration: duration,
      completed: true,
    );
  }

  // ============================================================
  // Cache Management
  // ============================================================

  /// Builds a cache key based on query parameters.
  String _buildCacheKey({
    required int page,
    required int pageSize,
    required bool completedOnly,
    String? animeId,
  }) {
    final parts = [
      _historyListKey,
      'p$page',
      's$pageSize',
      if (completedOnly) 'completed',
      if (animeId != null) 'anime_$animeId',
    ];
    return parts.join('_');
  }

  /// Invalidates all history list caches.
  Future<void> _invalidateHistoryCache() async {
    _ensureInitialized();
    final keysToDelete = <String>[];
    for (final key in _box!.keys) {
      if (key is String && key.startsWith(_historyListKey)) {
        keysToDelete.add(key);
      }
      if (key is String && key.startsWith(_lastFetchKey)) {
        keysToDelete.add(key);
      }
    }
    for (final key in keysToDelete) {
      await _box!.delete(key);
    }
  }

  /// Clears all cached watch history data.
  Future<void> clearCache() async {
    _ensureInitialized();
    await _box!.clear();
  }

  /// Gets the last fetch time for a cache key.
  DateTime? getLastFetchTime(String cacheKey) {
    _ensureInitialized();
    final lastFetchStr = _box!.get('${_lastFetchKey}_$cacheKey');
    if (lastFetchStr == null) return null;

    try {
      return DateTime.parse(lastFetchStr);
    } on FormatException {
      return null;
    }
  }

  /// Whether the cache has history data.
  bool get hasCachedHistory {
    _ensureInitialized();
    return _box!.keys.any(
      (key) => key is String && key.startsWith(_historyListKey),
    );
  }

  // ============================================================
  // Cleanup
  // ============================================================

  /// Disposes resources.
  Future<void> dispose() async {
    await _box?.close();
    _isInitialized = false;
  }
}
