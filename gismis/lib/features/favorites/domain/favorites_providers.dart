import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main.dart' as main_providers;
import '../../auth/domain/auth_providers.dart';
import '../data/favorites_repository.dart';

/// Provider for the FavoritesRepository instance.
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final cacheService = ref.watch(main_providers.cacheServiceProvider);

  return FavoritesRepository(dioClient: dioClient, cacheService: cacheService);
});

/// State class for favorites list with loading and error states.
class FavoritesState {
  const FavoritesState({
    this.favorites = const [],
    this.isLoading = false,
    this.error,
    this.isReordering = false,
  });

  final List<FavoriteAnime> favorites;
  final bool isLoading;
  final String? error;
  final bool isReordering;

  bool get isEmpty => favorites.isEmpty;
  int get count => favorites.length;

  FavoritesState copyWith({
    List<FavoriteAnime>? favorites,
    bool? isLoading,
    String? error,
    bool? isReordering,
  }) {
    return FavoritesState(
      favorites: favorites ?? this.favorites,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isReordering: isReordering ?? this.isReordering,
    );
  }
}

/// StateNotifier for managing favorites list with reordering support.
class FavoritesNotifier extends StateNotifier<FavoritesState> {
  FavoritesNotifier(this._repository) : super(const FavoritesState());

  final FavoritesRepository _repository;

  /// Loads favorites from the backend.
  Future<void> load() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      final favorites = await _repository.getFavorites();
      state = state.copyWith(favorites: favorites, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refreshes favorites from the backend.
  Future<void> refresh() async {
    state = const FavoritesState();
    await load();
  }

  /// Reorders favorites and persists the new order.
  ///
  /// [oldIndex] - The original index of the item
  /// [newIndex] - The new index for the item
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex || state.isReordering) return;

    // Create a copy of the list and perform the reorder
    final favorites = List<FavoriteAnime>.from(state.favorites);
    final item = favorites.removeAt(oldIndex);

    // Adjust newIndex if needed after removal
    final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    favorites.insert(adjustedIndex, item);

    // Update local state immediately for responsive UI
    state = state.copyWith(favorites: favorites, isReordering: true);

    // Persist the new order to backend
    try {
      final animeIds = favorites.map((f) => f.anime.id).toList();
      await _repository.updateFavoritesOrder(animeIds);
      state = state.copyWith(isReordering: false);
    } catch (e) {
      // Revert on error by reloading
      state = state.copyWith(isReordering: false, error: e.toString());
      await load();
    }
  }

  /// Removes an anime from favorites.
  ///
  /// [animeId] - The unique identifier of the anime to remove
  Future<void> removeFromFavorites(String animeId) async {
    // Optimistically remove from local state
    final updatedFavorites = state.favorites
        .where((f) => f.anime.id != animeId)
        .toList();

    state = state.copyWith(favorites: updatedFavorites);

    try {
      await _repository.removeFromFavorites(animeId);
    } catch (e) {
      // Revert on error by reloading
      state = state.copyWith(error: e.toString());
      await load();
    }
  }
}

/// Provider for favorites list with StateNotifier.
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
      final repository = ref.watch(favoritesRepositoryProvider);
      final notifier = FavoritesNotifier(repository)..load();
      return notifier;
    });

/// Provider for favorites count (for badges, etc.).
final favoritesCountProvider = Provider<int>((ref) {
  final state = ref.watch(favoritesProvider);
  return state.count;
});
