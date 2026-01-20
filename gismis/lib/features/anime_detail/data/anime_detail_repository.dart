import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/hive_cache.dart';
import '../../../shared/models/anime_detail.dart';

/// Repository for anime detail data operations.
///
/// Handles fetching anime details from the API and managing local cache.
/// Implements cache-first loading strategy for better UX.
class AnimeDetailRepository {
  AnimeDetailRepository({
    required DioClient dioClient,
    required CacheService cacheService,
  }) : _dioClient = dioClient,
       _cacheService = cacheService;
  final DioClient _dioClient;
  final CacheService _cacheService;

  /// Fetches anime detail by ID with caching support.
  ///
  /// [animeId] - The unique identifier of the anime
  /// [forceRefresh] - If true, bypasses cache and fetches from network
  ///
  /// Returns [AnimeDetail] with full information including platforms,
  /// schedule, episode state, and AI digest.
  Future<AnimeDetail> getAnimeDetail(
    String animeId, {
    bool forceRefresh = false,
  }) async {
    // Try cache first unless force refresh
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedAnimeDetail(animeId);
      if (cached != null) {
        // Return cached data but also trigger background refresh
        _refreshAnimeDetailInBackground(animeId);
        return cached;
      }
    }

    return _fetchAndCacheAnimeDetail(animeId);
  }

  /// Fetches anime detail from network and caches it.
  Future<AnimeDetail> _fetchAndCacheAnimeDetail(String animeId) async {
    try {
      // 调用 Edge Function 获取详情
      final response = await _dioClient.get<Map<String, dynamic>>(
        '/functions/v1/get-anime-detail/$animeId',
      );

      final data = response.data;
      if (data == null || data['success'] != true) {
        throw ApiException(
          type: ApiErrorType.serverError,
          message:
              (data?['error']?['message'] as String?) ??
              'Failed to fetch anime detail',
          statusCode: response.statusCode ?? 500,
        );
      }

      // 将 AnimeInfo 转换为 AnimeDetail
      final animeInfo = data['data'] as Map<String, dynamic>;
      final detail = _animeInfoToDetail(animeInfo);

      // Cache the result
      await _cacheService.cacheAnimeDetail(animeId, detail);

      return detail;
    } on ApiException {
      rethrow;
    }
  }

  /// 将 AnimeInfo (来自 Edge Function) 转换为 AnimeDetail
  AnimeDetail _animeInfoToDetail(Map<String, dynamic> json) {
    return AnimeDetail(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      titleJa: json['titleAliases'] != null
          ? (json['titleAliases'] as List).cast<String>().firstOrNull
          : null,
      coverUrl: json['coverUrl'] as String? ?? '',
      synopsis: json['synopsis'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      status: _parseStatus(json['status'] as String?),
      releaseYear: json['releaseYear'] as int?,
      episodeCount: json['episodeCount'] as int?,
      genres: (json['genres'] as List?)?.cast<String>() ?? [],
      platforms: [], // TMDB 不提供播放平台信息
      schedule: null, // TMDB 不提供时间表信息
      aiDigest: null, // AI 摘要需要单独获取
    );
  }

  String _parseStatus(String? status) {
    if (status == null) return 'ongoing';
    return switch (status.toLowerCase()) {
      'ongoing' => 'ongoing',
      'completed' => 'completed',
      'upcoming' => 'upcoming',
      _ => 'ongoing',
    };
  }

  /// Refreshes anime detail in background without blocking.
  void _refreshAnimeDetailInBackground(String animeId) {
    _fetchAndCacheAnimeDetail(animeId).catchError((_) {
      // Silently ignore background refresh errors
      return Future<AnimeDetail>.value(null as AnimeDetail);
    });
  }

  /// Fetches AI-generated digest for an anime.
  ///
  /// [animeId] - The unique identifier of the anime
  ///
  /// Returns [AiDigest] containing AI-generated summary and key points,
  /// or null if no digest is available.
  Future<AiDigest?> getAiDigest(String animeId) async {
    try {
      final response = await _dioClient.get<Map<String, dynamic>>(
        '/anime/$animeId/digest',
      );

      final data = response.data;
      if (data == null || data.isEmpty) {
        return null;
      }

      return AiDigest.fromJson(data);
    } on ApiException catch (e) {
      // Return null for 404 (no digest available)
      if (e.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// Gets cached anime detail for offline/cache-first display.
  ///
  /// Returns null if no cached data exists.
  Future<AnimeDetail?> getCachedAnimeDetail(String animeId) async {
    return _cacheService.getCachedAnimeDetail(animeId);
  }

  /// Checks if anime detail cache exists for a specific ID.
  Future<bool> hasAnimeDetailCache(String animeId) async {
    return _cacheService.hasAnimeDetailCache(animeId);
  }

  /// Checks if the anime detail cache is stale.
  ///
  /// [animeId] - The anime ID to check
  /// [maxAge] - Maximum age of cache before considered stale
  Future<bool> isAnimeDetailCacheStale(
    String animeId, {
    Duration maxAge = const Duration(hours: 1),
  }) async {
    return _cacheService.isCacheStale('detail_$animeId', maxAge);
  }

  /// Removes cached anime detail for a specific ID.
  Future<void> clearAnimeDetailCache(String animeId) async {
    await _cacheService.removeCachedAnimeDetail(animeId);
  }
}
