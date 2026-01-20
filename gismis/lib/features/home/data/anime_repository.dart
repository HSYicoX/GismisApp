import '../../../core/network/api_exception.dart';
import '../../../core/storage/hive_cache.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/models/anime.dart';

/// Result of a paginated API request.
class PaginatedResult<T> {
  const PaginatedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.hasMore,
  });
  final List<T> items;
  final int page;
  final int pageSize;
  final int totalItems;
  final bool hasMore;
}

/// Repository for anime-related data operations.
///
/// Handles fetching anime data from Edge Functions (aggregated from multiple platforms)
/// and managing local cache. Implements cache-first loading strategy for better UX.
class AnimeRepository {
  AnimeRepository({
    required SupabaseClient supabaseClient,
    required CacheService cacheService,
  }) : _supabaseClient = supabaseClient,
       _cacheService = cacheService;
  final SupabaseClient _supabaseClient;
  final CacheService _cacheService;

  /// Fetches a paginated list of anime from the aggregation Edge Function.
  ///
  /// This calls the `get-anime-list` Edge Function which aggregates data
  /// from multiple platforms (Bilibili, TMDB, etc.) and returns merged results.
  ///
  /// [page] - Page number (1-indexed)
  /// [pageSize] - Number of items per page (max 50)
  /// [forceRefresh] - If true, bypasses server-side cache
  ///
  /// Returns a [PaginatedResult] containing the anime list and pagination info.
  Future<PaginatedResult<Anime>> getAnimeList({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    try {
      print(
        '[AnimeRepository] Fetching anime list - page: $page, pageSize: $pageSize',
      );

      final response = await _supabaseClient
          .callPublicFunctionGet<Map<String, dynamic>>(
            'get-anime-list',
            queryParameters: {
              'page': page.toString(),
              'pageSize': pageSize.toString(),
              if (forceRefresh) 'refresh': 'true',
            },
          );

      print('[AnimeRepository] Response status: ${response.statusCode}');
      print('[AnimeRepository] Response data: ${response.data}');

      final data = response.data;
      if (data == null || data['success'] != true) {
        final errorMsg =
            (data?['error']?['message'] as String?) ??
            'Failed to fetch anime list';
        print('[AnimeRepository] Error: $errorMsg');
        throw ApiException(
          type: ApiErrorType.serverError,
          message: errorMsg,
          statusCode: response.statusCode ?? 500,
        );
      }

      final animeList =
          (data['data'] as List<dynamic>?)
              ?.map((e) => _animeFromEdgeFunction(e as Map<String, dynamic>))
              .toList() ??
          [];

      print('[AnimeRepository] Parsed ${animeList.length} anime');

      final pagination = data['meta']?['pagination'] as Map<String, dynamic>?;
      final totalItems = pagination?['total'] as int? ?? animeList.length;
      final hasMore =
          pagination?['hasMore'] as bool? ?? animeList.length == pageSize;

      // Cache the first page of results
      if (page == 1) {
        await _cacheService.cacheAnimeList(animeList);
      }

      return PaginatedResult(
        items: animeList,
        page: page,
        pageSize: pageSize,
        totalItems: totalItems,
        hasMore: hasMore,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      print('[AnimeRepository] Unexpected error: $e');
      rethrow;
    }
  }

  /// Searches anime by keyword across multiple platforms.
  ///
  /// This calls the `search-anime` Edge Function which searches across
  /// all configured platforms and returns merged, deduplicated results.
  ///
  /// [keyword] - Search term to filter anime
  /// [page] - Page number (1-indexed), used for client-side pagination
  /// [pageSize] - Number of items per page
  /// [forceRefresh] - If true, bypasses server-side cache
  ///
  /// Returns a [PaginatedResult] containing the search results.
  Future<PaginatedResult<Anime>> searchAnime({
    required String keyword,
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    if (keyword.trim().isEmpty) {
      return PaginatedResult(
        items: [],
        page: page,
        pageSize: pageSize,
        totalItems: 0,
        hasMore: false,
      );
    }

    try {
      // The search-anime endpoint returns all results at once (up to limit)
      // We handle pagination client-side
      final limit = page * pageSize;

      final response = await _supabaseClient
          .callPublicFunctionGet<Map<String, dynamic>>(
            'search-anime',
            queryParameters: {'q': keyword.trim(), 'limit': limit.toString()},
          );

      final data = response.data;
      if (data == null || data['success'] != true) {
        throw ApiException(
          type: ApiErrorType.serverError,
          message:
              (data?['error']?['message'] as String?) ??
              'Failed to search anime',
          statusCode: response.statusCode ?? 500,
        );
      }

      final allResults =
          (data['data']?['results'] as List<dynamic>?)
              ?.map((e) => _animeFromEdgeFunction(e as Map<String, dynamic>))
              .toList() ??
          [];

      // Client-side pagination
      final startIndex = (page - 1) * pageSize;
      final endIndex = startIndex + pageSize;
      final pageResults = startIndex < allResults.length
          ? allResults.sublist(
              startIndex,
              endIndex > allResults.length ? allResults.length : endIndex,
            )
          : <Anime>[];

      return PaginatedResult(
        items: pageResults,
        page: page,
        pageSize: pageSize,
        totalItems: allResults.length,
        hasMore: endIndex < allResults.length,
      );
    } on ApiException {
      rethrow;
    }
  }

  /// Fetches trending anime (top rated).
  ///
  /// Returns a list of currently trending anime based on rating.
  /// Falls back to direct PostgREST query for now.
  Future<List<Anime>> getTrendingAnime() async {
    try {
      final result = await _supabaseClient.query<Anime>(
        table: 'anime',
        fromJson: _animeFromSupabase,
        order: 'rating.desc.nullslast',
        limit: 10,
        countTotal: false,
      );

      return result.items;
    } on ApiException {
      rethrow;
    }
  }

  /// Fetches anime that have updates today.
  ///
  /// Returns a list of anime with schedule entries for today.
  /// Falls back to direct PostgREST query for now.
  Future<List<Anime>> getTodayUpdates() async {
    try {
      final today = DateTime.now().weekday;
      // Convert ISO weekday (1=Monday, 7=Sunday) to DB format (0=Sunday, 6=Saturday)
      final dbDayOfWeek = today == 7 ? 0 : today;

      final result = await _supabaseClient.query<Anime>(
        table: 'anime',
        fromJson: _animeFromSupabase,
        select: '*,schedule!inner(*)',
        filters: {'schedule.day_of_week': 'eq.$dbDayOfWeek'},
        order: 'schedule.air_time.asc',
        countTotal: false,
      );

      return result.items;
    } on ApiException {
      rethrow;
    }
  }

  /// Converts Edge Function AnimeInfo JSON to Anime model.
  /// Maps the aggregated data format to the shared Anime model.
  static Anime _animeFromEdgeFunction(Map<String, dynamic> json) {
    return Anime(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      titleAlias: _parseStringList(json['titleAliases']),
      coverUrl: json['coverUrl'] as String? ?? '',
      summary: json['synopsis'] as String?,
      status: _parseEdgeFunctionStatus(json['status'] as String?),
      updatedAt: DateTime.now(), // Edge function doesn't provide this
    );
  }

  /// Converts Supabase anime JSON to Anime model.
  /// Maps Supabase field names to the shared Anime model.
  static Anime _animeFromSupabase(Map<String, dynamic> json) {
    return Anime(
      id: json['id'] as String,
      title: json['title'] as String,
      titleAlias: _parseStringList(json['title_ja']),
      coverUrl: (json['cover_url'] as String?) ?? '',
      summary: json['synopsis'] as String?,
      status: _parseStatus(json['status'] as String?),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  static AnimeStatus _parseStatus(String? status) {
    if (status == null) return AnimeStatus.ongoing;
    return switch (status.toLowerCase()) {
      'airing' || 'ongoing' => AnimeStatus.ongoing,
      'completed' || 'finished' => AnimeStatus.completed,
      'upcoming' => AnimeStatus.upcoming,
      'hiatus' => AnimeStatus.hiatus,
      _ => AnimeStatus.ongoing,
    };
  }

  static AnimeStatus _parseEdgeFunctionStatus(String? status) {
    if (status == null) return AnimeStatus.ongoing;
    return switch (status.toLowerCase()) {
      'ongoing' => AnimeStatus.ongoing,
      'completed' => AnimeStatus.completed,
      'upcoming' => AnimeStatus.upcoming,
      _ => AnimeStatus.ongoing,
    };
  }

  /// Gets cached anime list for offline/cache-first display.
  ///
  /// Returns null if no cached data exists.
  Future<List<Anime>?> getCachedAnimeList() async {
    return _cacheService.getCachedAnimeList();
  }

  /// Checks if the anime list cache is stale.
  ///
  /// [maxAge] - Maximum age of cache before considered stale
  Future<bool> isAnimeListCacheStale({
    Duration maxAge = const Duration(minutes: 30),
  }) async {
    return _cacheService.isCacheStale('anime_list', maxAge);
  }

  /// Checks if anime list cache exists.
  Future<bool> hasAnimeListCache() async {
    return _cacheService.hasAnimeListCache();
  }
}

/// Utility function to filter anime list by search query.
///
/// This is a pure function that can be used for local filtering
/// and is also useful for property-based testing.
///
/// Returns anime where title or any alias contains the query (case-insensitive).
List<Anime> filterAnimeByQuery(List<Anime> animes, String query) {
  if (query.trim().isEmpty) {
    return animes;
  }

  final lowerQuery = query.toLowerCase().trim();

  return animes.where((anime) {
    // Check title
    if (anime.title.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    // Check aliases
    for (final alias in anime.titleAlias) {
      if (alias.toLowerCase().contains(lowerQuery)) {
        return true;
      }
    }

    return false;
  }).toList();
}

/// Utility function to accumulate paginated results.
///
/// This is a pure function that merges new page results with existing results,
/// ensuring no duplicates based on anime ID.
///
/// [existing] - Current accumulated list
/// [newItems] - Items from the new page
///
/// Returns combined list without duplicates.
List<Anime> accumulatePaginatedResults(
  List<Anime> existing,
  List<Anime> newItems,
) {
  final existingIds = existing.map((a) => a.id).toSet();
  final uniqueNewItems = newItems.where((a) => !existingIds.contains(a.id));

  return [...existing, ...uniqueNewItems];
}
