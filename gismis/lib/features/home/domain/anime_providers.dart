import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/hive_cache.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../main.dart' as main_providers;
import '../../../shared/models/anime.dart';
import '../data/anime_repository.dart';

/// Provider for the AnimeRepository instance.
final animeRepositoryProvider = Provider<AnimeRepository>((ref) {
  final supabaseClient = ref.watch(supabaseClientProvider);
  final cacheService = ref.watch(main_providers.cacheServiceProvider);

  return AnimeRepository(
    supabaseClient: supabaseClient,
    cacheService: cacheService,
  );
});

/// Provider for the current search query.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// State class for paginated anime list.
class AnimeListState {
  const AnimeListState({
    this.animes = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 0,
    this.hasMore = true,
    this.isFromCache = false,
  });
  final List<Anime> animes;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final bool hasMore;
  final bool isFromCache;

  AnimeListState copyWith({
    List<Anime>? animes,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
    bool? hasMore,
    bool? isFromCache,
  }) {
    return AnimeListState(
      animes: animes ?? this.animes,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }
}

/// StateNotifier for managing paginated anime list with cache-first strategy.
class AnimeListNotifier extends StateNotifier<AnimeListState> {
  AnimeListNotifier(this._repository, {String? searchQuery})
    : _searchQuery = searchQuery,
      super(const AnimeListState());
  final AnimeRepository _repository;
  final String? _searchQuery;

  /// Loads the initial page of anime with cache-first strategy.
  ///
  /// If cached data exists, it displays immediately while fetching fresh data.
  Future<void> loadInitial() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    // Cache-first: Try to load from cache first (only for non-search queries)
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      try {
        final cachedAnimes = await _repository.getCachedAnimeList();
        if (cachedAnimes != null && cachedAnimes.isNotEmpty) {
          state = state.copyWith(
            animes: cachedAnimes,
            isFromCache: true,
            isLoading: true, // Still loading fresh data
          );
        }
      } catch (_) {
        // Ignore cache errors, proceed to fetch from network
      }
    }

    // Fetch fresh data from network
    try {
      final PaginatedResult<Anime> result;
      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        // Use search endpoint for search queries
        result = await _repository.searchAnime(keyword: _searchQuery!);
      } else {
        // Use anime list endpoint for browsing
        result = await _repository.getAnimeList();
      }

      state = state.copyWith(
        animes: result.items,
        isLoading: false,
        currentPage: 1,
        hasMore: result.hasMore,
        isFromCache: false,
      );
    } catch (e) {
      // If we have cached data, keep showing it with error indicator
      if (state.animes.isNotEmpty) {
        state = state.copyWith(isLoading: false, error: e.toString());
      } else {
        state = state.copyWith(
          isLoading: false,
          error: e.toString(),
          animes: [],
        );
      }
    }
  }

  /// Loads the next page of anime (infinite scroll).
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      final PaginatedResult<Anime> result;

      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        // Use search endpoint for search queries
        result = await _repository.searchAnime(
          keyword: _searchQuery!,
          page: nextPage,
        );
      } else {
        // Use anime list endpoint for browsing
        result = await _repository.getAnimeList(page: nextPage);
      }

      // Accumulate results without duplicates
      final accumulated = accumulatePaginatedResults(
        state.animes,
        result.items,
      );

      state = state.copyWith(
        animes: accumulated,
        isLoadingMore: false,
        currentPage: nextPage,
        hasMore: result.hasMore,
        isFromCache: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Refreshes the anime list from the beginning.
  Future<void> refresh() async {
    state = const AnimeListState();
    await loadInitial();
  }
}

/// Provider for the main anime list with pagination.
final animeListProvider =
    StateNotifierProvider<AnimeListNotifier, AnimeListState>((ref) {
      final repository = ref.watch(animeRepositoryProvider);
      final notifier = AnimeListNotifier(repository);

      // Auto-load initial data
      notifier.loadInitial();

      return notifier;
    });

/// Provider for search results with pagination.
///
/// This provider is family-based, creating a new notifier for each search query.
final searchResultsProvider =
    StateNotifierProvider.family<AnimeListNotifier, AnimeListState, String>((
      ref,
      query,
    ) {
      final repository = ref.watch(animeRepositoryProvider);
      final notifier = AnimeListNotifier(repository, searchQuery: query);

      if (query.isNotEmpty) {
        notifier.loadInitial();
      }

      return notifier;
    });

/// Provider for trending anime.
final trendingAnimeProvider = FutureProvider<List<Anime>>((ref) async {
  final repository = ref.watch(animeRepositoryProvider);
  return repository.getTrendingAnime();
});

/// Provider for today's anime updates.
final todayUpdatesProvider = FutureProvider<List<Anime>>((ref) async {
  final repository = ref.watch(animeRepositoryProvider);
  return repository.getTodayUpdates();
});

/// Provider that combines search query with filtered results.
///
/// When search query is empty, returns the main anime list.
/// When search query is not empty, returns filtered/searched results.
final filteredAnimeListProvider = Provider<AnimeListState>((ref) {
  final query = ref.watch(searchQueryProvider);

  if (query.isEmpty) {
    return ref.watch(animeListProvider);
  } else {
    return ref.watch(searchResultsProvider(query));
  }
});
