import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main.dart' as main_providers;
import '../../../shared/models/anime_detail.dart';
import '../../../shared/models/user_anime_follow.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/anime_detail_repository.dart';
import '../data/follow_repository.dart';

/// Provider for the AnimeDetailRepository instance.
final animeDetailRepositoryProvider = Provider<AnimeDetailRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final cacheService = ref.watch(main_providers.cacheServiceProvider);

  return AnimeDetailRepository(
    dioClient: dioClient,
    cacheService: cacheService,
  );
});

/// Provider for the FollowRepository instance.
final followRepositoryProvider = Provider<FollowRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final cacheService = ref.watch(main_providers.cacheServiceProvider);

  return FollowRepository(dioClient: dioClient, cacheService: cacheService);
});

/// State class for anime detail with loading and error states.
class AnimeDetailState {
  const AnimeDetailState({
    this.detail,
    this.isLoading = false,
    this.error,
    this.isFromCache = false,
  });
  final AnimeDetail? detail;
  final bool isLoading;
  final String? error;
  final bool isFromCache;

  AnimeDetailState copyWith({
    AnimeDetail? detail,
    bool? isLoading,
    String? error,
    bool? isFromCache,
  }) {
    return AnimeDetailState(
      detail: detail ?? this.detail,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }
}

/// StateNotifier for managing anime detail state.
class AnimeDetailNotifier extends StateNotifier<AnimeDetailState> {
  AnimeDetailNotifier(this._repository, this._animeId)
    : super(const AnimeDetailState());
  final AnimeDetailRepository _repository;
  final String _animeId;

  /// Loads anime detail with cache-first strategy.
  Future<void> load() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    // Try cache first
    try {
      final cached = await _repository.getCachedAnimeDetail(_animeId);
      if (cached != null) {
        state = state.copyWith(
          detail: cached,
          isFromCache: true,
          isLoading: true, // Still loading fresh data
        );
      }
    } catch (_) {
      // Ignore cache errors
    }

    // Fetch fresh data
    try {
      final detail = await _repository.getAnimeDetail(
        _animeId,
        forceRefresh: true,
      );
      state = state.copyWith(
        detail: detail,
        isLoading: false,
        isFromCache: false,
      );
    } catch (e) {
      if (state.detail != null) {
        // Keep cached data but show error
        state = state.copyWith(isLoading: false, error: e.toString());
      } else {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  /// Refreshes anime detail from network.
  Future<void> refresh() async {
    state = const AnimeDetailState();
    await load();
  }
}

/// Provider for anime detail with family (per anime ID).
final animeDetailProvider =
    StateNotifierProvider.family<AnimeDetailNotifier, AnimeDetailState, String>(
      (ref, animeId) {
        final repository = ref.watch(animeDetailRepositoryProvider);
        final notifier = AnimeDetailNotifier(repository, animeId)..load();
        return notifier;
      },
    );

/// State class for follow status.
class FollowState {
  const FollowState({this.follow, this.isLoading = false, this.error});
  final UserAnimeFollow? follow;
  final bool isLoading;
  final String? error;

  bool get isFollowed => follow != null;
  bool get isFavorite => follow?.isFavorite ?? false;

  FollowState copyWith({
    UserAnimeFollow? follow,
    bool? isLoading,
    String? error,
    bool clearFollow = false,
  }) {
    return FollowState(
      follow: clearFollow ? null : (follow ?? this.follow),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// StateNotifier for managing follow status.
class FollowStatusNotifier extends StateNotifier<FollowState> {
  FollowStatusNotifier(this._repository, this._animeId)
    : super(const FollowState());
  final FollowRepository _repository;
  final String _animeId;

  /// Loads follow status for the anime.
  Future<void> load() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      final follow = await _repository.getFollowStatus(_animeId);
      state = state.copyWith(
        follow: follow,
        isLoading: false,
        clearFollow: follow == null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Toggles follow status.
  Future<void> toggleFollow() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      if (state.isFollowed) {
        await _repository.unfollowAnime(_animeId);
        state = state.copyWith(isLoading: false, clearFollow: true);
      } else {
        final follow = await _repository.followAnime(_animeId);
        state = state.copyWith(follow: follow, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Toggles favorite status.
  Future<void> toggleFavorite() async {
    if (state.isLoading || !state.isFollowed) return;

    state = state.copyWith(isLoading: true);

    try {
      final follow = await _repository.updateFavorite(
        _animeId,
        isFavorite: !state.isFavorite,
      );
      state = state.copyWith(follow: follow, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Updates progress episode.
  Future<void> updateProgress(int episode) async {
    if (state.isLoading || !state.isFollowed) return;

    state = state.copyWith(isLoading: true);

    try {
      final follow = await _repository.updateProgress(
        _animeId,
        progressEpisode: episode,
      );
      state = state.copyWith(follow: follow, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

/// Provider for follow status with family (per anime ID).
final followStatusProvider =
    StateNotifierProvider.family<FollowStatusNotifier, FollowState, String>((
      ref,
      animeId,
    ) {
      final repository = ref.watch(followRepositoryProvider);
      final notifier = FollowStatusNotifier(repository, animeId)..load();
      return notifier;
    });

/// Provider for AI digest with family (per anime ID).
final aiDigestProvider = FutureProvider.family<AiDigest?, String>((
  ref,
  animeId,
) async {
  final repository = ref.watch(animeDetailRepositoryProvider);
  return repository.getAiDigest(animeId);
});

/// Provider for all followed animes.
final followedAnimesProvider = FutureProvider<List<UserAnimeFollow>>((
  ref,
) async {
  final repository = ref.watch(followRepositoryProvider);
  return repository.getFollowedAnimes();
});

/// Provider for favorite animes only.
final favoriteAnimesProvider = FutureProvider<List<UserAnimeFollow>>((
  ref,
) async {
  final follows = await ref.watch(followedAnimesProvider.future);
  return follows.where((f) => f.isFavorite).toList();
});
