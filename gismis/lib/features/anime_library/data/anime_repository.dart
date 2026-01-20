/// Anime Library Repository for Supabase PostgREST queries.
///
/// This repository handles public read operations for anime data
/// using PostgREST direct queries with RLS public access.
library;

import '../../../core/storage/hive_cache.dart';
import '../../../core/supabase/paginated_result.dart';
import '../../../core/supabase/supabase_client.dart';
import 'models/models.dart';

/// Repository for anime library data operations via Supabase.
///
/// Access mode: PostgREST direct connection (public read-only, RLS allows)
///
/// Features:
/// - Paginated anime list queries
/// - Full-text search on title
/// - Filtering by genre, status, year
/// - Sorting by various fields
/// - Hive caching for offline access
class AnimeLibraryRepository {
  AnimeLibraryRepository({
    required SupabaseClient client,
    required CacheService cache,
  }) : _client = client,
       _cache = cache;

  final SupabaseClient _client;
  final CacheService _cache;

  static const _cacheKeyPrefix = 'anime_library';
  static const _cacheDuration = Duration(hours: 1);

  /// Fetches a paginated list of anime.
  ///
  /// Parameters:
  /// - [page]: Page number (1-indexed)
  /// - [pageSize]: Number of items per page (default: 20)
  /// - [genre]: Filter by genre (uses PostgreSQL array contains)
  /// - [status]: Filter by airing status
  /// - [year]: Filter by start year
  /// - [sortBy]: Sort field and direction (e.g., 'rating.desc', 'start_date.asc')
  ///
  /// Returns a [PaginatedResult] containing anime items and pagination metadata.
  Future<PaginatedResult<AnimeLibraryItem>> getAnimeList({
    int page = 1,
    int pageSize = 20,
    String? genre,
    AnimeLibraryStatus? status,
    int? year,
    String sortBy = 'rating.desc.nullslast',
  }) async {
    final offset = (page - 1) * pageSize;

    final filters = <String, String>{};
    if (genre != null) {
      filters['genres'] = 'cs.{$genre}';
    }
    if (status != null) {
      filters['status'] = 'eq.${status.value}';
    }
    if (year != null) {
      filters['start_date'] = 'gte.$year-01-01&start_date=lt.${year + 1}-01-01';
    }

    final result = await _client.query<AnimeLibraryItem>(
      table: 'anime',
      fromJson: AnimeLibraryItem.fromJson,
      filters: filters.isEmpty ? null : filters,
      order: sortBy,
      limit: pageSize,
      offset: offset,
    );

    return result;
  }

  /// Searches anime by title using full-text search.
  ///
  /// Searches both primary title and Japanese title (case-insensitive).
  ///
  /// Parameters:
  /// - [query]: Search query string
  /// - [limit]: Maximum number of results (default: 20)
  ///
  /// Returns a list of matching anime.
  Future<List<AnimeLibraryItem>> searchAnime(
    String query, {
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final escapedQuery = query.replaceAll("'", "''");

    final result = await _client.query<AnimeLibraryItem>(
      table: 'anime',
      fromJson: AnimeLibraryItem.fromJson,
      filters: {
        'or': '(title.ilike.*$escapedQuery*,title_ja.ilike.*$escapedQuery*)',
      },
      limit: limit,
      countTotal: false,
    );

    return result.items;
  }

  /// Fetches anime that have updates today.
  ///
  /// Queries anime with schedule entries for the current day of week.
  ///
  /// Returns a list of anime airing today, sorted by air time.
  Future<List<AnimeLibraryItem>> getTodayUpdates() async {
    final today = DateTime.now().weekday;

    final result = await _client.query<AnimeLibraryItem>(
      table: 'anime',
      fromJson: AnimeLibraryItem.fromJson,
      select: '*,schedule!inner(*)',
      filters: {'schedule.day_of_week': 'eq.$today'},
      order: 'schedule.air_time.asc',
      countTotal: false,
    );

    return result.items;
  }

  /// Fetches a single anime by ID with full details.
  ///
  /// Parameters:
  /// - [id]: The anime UUID
  ///
  /// Returns the anime details or throws if not found.
  Future<AnimeLibraryItem> getAnimeById(String id) async {
    final anime = await _client.querySingle<AnimeLibraryItem>(
      table: 'anime',
      fromJson: AnimeLibraryItem.fromJson,
      select: '*,anime_platform_links(*)',
      filters: {'id': 'eq.$id'},
    );

    return anime;
  }

  /// Gets cached anime list for offline/cache-first display.
  ///
  /// Returns null if no cached data exists.
  Future<List<AnimeLibraryItem>?> getCachedAnimeList() async {
    try {
      final cached = await _cache.getCachedAnimeList();
      if (cached == null) return null;

      // Convert shared Anime model to AnimeLibraryItem
      return cached
          .map(
            (a) => AnimeLibraryItem(
              id: a.id,
              title: a.title,
              titleJa: a.titleAlias.isNotEmpty ? a.titleAlias.first : null,
              coverUrl: a.coverUrl,
              status: _mapStatus(a.status),
            ),
          )
          .toList();
    } on Exception {
      return null;
    }
  }

  /// Checks if the anime list cache is stale.
  Future<bool> isAnimeListCacheStale() async {
    return _cache.isCacheStale(_cacheKeyPrefix, _cacheDuration);
  }

  AnimeLibraryStatus _mapStatus(dynamic status) {
    if (status == null) return AnimeLibraryStatus.upcoming;
    final statusStr = status.toString().toLowerCase();
    return switch (statusStr) {
      'airing' || 'ongoing' => AnimeLibraryStatus.airing,
      'completed' || 'finished' => AnimeLibraryStatus.completed,
      _ => AnimeLibraryStatus.upcoming,
    };
  }
}

/// Utility function to filter anime list by search query.
///
/// This is a pure function for local filtering and property-based testing.
///
/// Returns anime where title or Japanese title contains the query (case-insensitive).
List<AnimeLibraryItem> filterAnimeLibraryByQuery(
  List<AnimeLibraryItem> animes,
  String query,
) {
  if (query.trim().isEmpty) {
    return animes;
  }

  final lowerQuery = query.toLowerCase().trim();

  return animes.where((anime) {
    if (anime.title.toLowerCase().contains(lowerQuery)) {
      return true;
    }
    if (anime.titleJa?.toLowerCase().contains(lowerQuery) ?? false) {
      return true;
    }
    return false;
  }).toList();
}

/// Utility function to accumulate paginated results.
///
/// Merges new page results with existing results, ensuring no duplicates.
///
/// [existing] - Current accumulated list
/// [newItems] - Items from the new page
///
/// Returns combined list without duplicates.
List<AnimeLibraryItem> accumulateAnimeLibraryResults(
  List<AnimeLibraryItem> existing,
  List<AnimeLibraryItem> newItems,
) {
  final existingIds = existing.map((a) => a.id).toSet();
  final uniqueNewItems = newItems.where((a) => !existingIds.contains(a.id));

  return [...existing, ...uniqueNewItems];
}
