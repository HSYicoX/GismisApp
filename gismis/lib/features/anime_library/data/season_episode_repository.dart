/// Season and Episode Repository for Supabase PostgREST queries.
///
/// This repository handles public read operations for anime seasons
/// and episodes using PostgREST direct queries with RLS public access.
library;

import '../../../core/supabase/paginated_result.dart';
import '../../../core/supabase/supabase_client.dart';
import 'models/models.dart';

/// Repository for anime season and episode data operations via Supabase.
///
/// Access mode: PostgREST direct connection (public read-only, RLS allows)
///
/// Features:
/// - Season list queries by anime
/// - Episode list queries by season
/// - Nested queries (seasons with episodes)
/// - Latest episodes across all anime
class SeasonEpisodeRepository {
  SeasonEpisodeRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  /// Fetches all seasons for a specific anime.
  ///
  /// Parameters:
  /// - [animeId]: The anime UUID
  ///
  /// Returns a list of seasons ordered by season number.
  Future<List<AnimeSeason>> getSeasons(String animeId) async {
    final result = await _client.query<AnimeSeason>(
      table: 'anime_seasons',
      fromJson: AnimeSeason.fromJson,
      filters: {'anime_id': 'eq.$animeId'},
      order: 'season_number.asc',
      countTotal: false,
    );

    return result.items;
  }

  /// Fetches all episodes for a specific season.
  ///
  /// Parameters:
  /// - [seasonId]: The season UUID
  ///
  /// Returns a list of episodes ordered by episode number.
  Future<List<Episode>> getEpisodes(String seasonId) async {
    final result = await _client.query<Episode>(
      table: 'episodes',
      fromJson: Episode.fromJson,
      filters: {'season_id': 'eq.$seasonId'},
      order: 'episode_number.asc',
      countTotal: false,
    );

    return result.items;
  }

  /// Fetches paginated episodes for a specific season.
  ///
  /// Parameters:
  /// - [seasonId]: The season UUID
  /// - [page]: Page number (1-indexed)
  /// - [pageSize]: Number of items per page
  ///
  /// Returns a [PaginatedResult] containing episodes and pagination metadata.
  Future<PaginatedResult<Episode>> getEpisodesPaginated({
    required String seasonId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final offset = (page - 1) * pageSize;

    return _client.query<Episode>(
      table: 'episodes',
      fromJson: Episode.fromJson,
      filters: {'season_id': 'eq.$seasonId'},
      order: 'episode_number.asc',
      limit: pageSize,
      offset: offset,
    );
  }

  /// Fetches seasons with nested episodes for a specific anime.
  ///
  /// This uses PostgREST's nested query feature to fetch seasons
  /// along with their episodes in a single request.
  ///
  /// Parameters:
  /// - [animeId]: The anime UUID
  ///
  /// Returns a list of seasons with their episodes populated.
  Future<List<AnimeSeason>> getSeasonsWithEpisodes(String animeId) async {
    final result = await _client.query<AnimeSeason>(
      table: 'anime_seasons',
      fromJson: AnimeSeason.fromJson,
      select: '*,episodes(*)',
      filters: {'anime_id': 'eq.$animeId'},
      order: 'season_number.asc',
      countTotal: false,
    );

    return result.items;
  }

  /// Fetches the latest episodes across all anime.
  ///
  /// Returns episodes that have recently aired, sorted by air date descending.
  ///
  /// Parameters:
  /// - [limit]: Maximum number of episodes to return (default: 20)
  ///
  /// Returns a list of recent episodes with platform links.
  Future<List<Episode>> getLatestEpisodes({int limit = 20}) async {
    final result = await _client.query<Episode>(
      table: 'episodes',
      fromJson: Episode.fromJson,
      select: '*,episode_platform_links(*)',
      filters: {'air_date': 'not.is.null'},
      order: 'air_date.desc',
      limit: limit,
      countTotal: false,
    );

    return result.items;
  }

  /// Fetches a single episode by ID with full details.
  ///
  /// Parameters:
  /// - [id]: The episode UUID
  ///
  /// Returns the episode details with platform links or throws if not found.
  Future<Episode> getEpisodeById(String id) async {
    return _client.querySingle<Episode>(
      table: 'episodes',
      fromJson: Episode.fromJson,
      select: '*,episode_platform_links(*)',
      filters: {'id': 'eq.$id'},
    );
  }

  /// Fetches a single season by ID with full details.
  ///
  /// Parameters:
  /// - [id]: The season UUID
  ///
  /// Returns the season details or throws if not found.
  Future<AnimeSeason> getSeasonById(String id) async {
    return _client.querySingle<AnimeSeason>(
      table: 'anime_seasons',
      fromJson: AnimeSeason.fromJson,
      filters: {'id': 'eq.$id'},
    );
  }

  /// Fetches episodes that aired on a specific date.
  ///
  /// Parameters:
  /// - [date]: The date to query
  ///
  /// Returns a list of episodes that aired on the given date.
  Future<List<Episode>> getEpisodesByAirDate(DateTime date) async {
    final dateStr = date.toIso8601String().split('T').first;

    final result = await _client.query<Episode>(
      table: 'episodes',
      fromJson: Episode.fromJson,
      select: '*,episode_platform_links(*)',
      filters: {'air_date': 'eq.$dateStr'},
      order: 'episode_number.asc',
      countTotal: false,
    );

    return result.items;
  }
}
