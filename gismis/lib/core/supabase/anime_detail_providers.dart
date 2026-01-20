/// Riverpod providers for anime detail aggregated queries.
///
/// This file provides the [animeDetailProvider] which fetches anime details
/// with seasons and source material in parallel for optimal performance.
///
/// Requirements: 3.1 - Aggregated anime detail query
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/anime_library/data/models/models.dart';
import 'supabase_repository_providers.dart';

/// Aggregated anime detail containing anime, seasons, and source material.
///
/// This class combines data from multiple repositories into a single
/// cohesive view for the anime detail screen.
class AggregatedAnimeDetail {
  const AggregatedAnimeDetail({
    required this.anime,
    required this.seasons,
    this.sourceMaterial,
  });

  /// The anime basic information.
  final AnimeLibraryItem anime;

  /// All seasons with their episodes.
  final List<AnimeSeason> seasons;

  /// The source material (novel, manga, etc.) if available.
  final SourceMaterial? sourceMaterial;

  /// Total episode count across all seasons.
  int get totalEpisodes => seasons.fold(
    0,
    (sum, season) => sum + (season.episodes?.length ?? season.episodeCount),
  );

  /// Whether the anime has source material.
  bool get hasSourceMaterial => sourceMaterial != null;

  /// Whether the anime is currently airing.
  bool get isAiring => anime.status == AnimeLibraryStatus.airing;

  /// The latest season (highest season number).
  AnimeSeason? get latestSeason => seasons.isNotEmpty
      ? seasons.reduce((a, b) => a.seasonNumber > b.seasonNumber ? a : b)
      : null;
}

/// Provider for fetching aggregated anime detail.
///
/// Fetches anime, seasons (with episodes), and source material in parallel
/// for optimal performance. Uses [FutureProvider.family] to cache results
/// per anime ID.
///
/// Usage:
/// ```dart
/// final detailAsync = ref.watch(animeDetailProvider(animeId));
///
/// detailAsync.when(
///   data: (detail) => AnimeDetailView(detail: detail),
///   loading: () => const LoadingIndicator(),
///   error: (error, stack) => ErrorView(error: error),
/// );
/// ```
///
/// Requirements: 3.1 - Parallel fetching of anime, seasons, sourceMaterial
final animeDetailProvider =
    FutureProvider.family<AggregatedAnimeDetail, String>((ref, animeId) async {
      final animeRepo = ref.read(animeLibraryRepositoryProvider);
      final seasonRepo = ref.read(seasonEpisodeRepositoryProvider);
      final sourceRepo = ref.read(sourceMaterialRepositoryProvider);

      // Fetch all data in parallel for optimal performance
      // Using record type for type-safe parallel fetching
      final (anime, seasons, sourceMaterial) = await (
        animeRepo.getAnimeById(animeId),
        seasonRepo.getSeasonsWithEpisodes(animeId),
        sourceRepo.getSourceMaterial(animeId),
      ).wait;

      return AggregatedAnimeDetail(
        anime: anime,
        seasons: seasons,
        sourceMaterial: sourceMaterial,
      );
    });

/// Provider for refreshing anime detail.
///
/// Call this to force a refresh of the anime detail data.
/// Returns a function that can be called to trigger the refresh.
///
/// Usage:
/// ```dart
/// final refresh = ref.read(refreshAnimeDetailProvider(animeId));
/// await refresh();
/// ```
final refreshAnimeDetailProvider =
    Provider.family<Future<void> Function(), String>((ref, animeId) {
      return () async {
        ref.invalidate(animeDetailProvider(animeId));
      };
    });
