import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/hive_cache.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/models/user_anime_follow.dart';

/// A combined model representing a favorite anime with its follow data.
class FavoriteAnime {
  const FavoriteAnime({required this.anime, required this.follow});

  final Anime anime;
  final UserAnimeFollow follow;

  FavoriteAnime copyWith({Anime? anime, UserAnimeFollow? follow}) {
    return FavoriteAnime(
      anime: anime ?? this.anime,
      follow: follow ?? this.follow,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FavoriteAnime) return false;
    return anime == other.anime && follow == other.follow;
  }

  @override
  int get hashCode => Object.hash(anime, follow);
}

/// Repository for managing user's favorite anime collection.
///
/// Handles fetching favorites, updating order, and syncing with backend.
class FavoritesRepository {
  FavoritesRepository({
    required DioClient dioClient,
    required CacheService cacheService,
  }) : _dioClient = dioClient,
       _cacheService = cacheService;

  final DioClient _dioClient;
  final CacheService _cacheService;

  /// Gets all favorite anime for the current user.
  ///
  /// Returns a list of [FavoriteAnime] objects sorted by user's custom order.
  Future<List<FavoriteAnime>> getFavorites() async {
    try {
      final response = await _dioClient.get<Map<String, dynamic>>(
        '/me/favorites',
      );

      final data = response.data!;
      final itemsJson = data['items'] as List<dynamic>? ?? [];

      final favorites = itemsJson.map((json) {
        final itemMap = json as Map<String, dynamic>;
        final animeJson = itemMap['anime'] as Map<String, dynamic>;
        final followJson = itemMap['follow'] as Map<String, dynamic>;

        return FavoriteAnime(
          anime: Anime.fromJson(animeJson),
          follow: UserAnimeFollow.fromJson(followJson),
        );
      }).toList();

      // Cache the favorites order
      await _cacheFavoritesOrder(favorites.map((f) => f.anime.id).toList());

      return favorites;
    } on ApiException {
      rethrow;
    }
  }

  /// Updates the order of favorites.
  ///
  /// [animeIds] - List of anime IDs in the desired order
  Future<void> updateFavoritesOrder(List<String> animeIds) async {
    try {
      await _dioClient.put<void>(
        '/me/favorites/order',
        data: {'anime_ids': animeIds},
      );

      // Update local cache
      await _cacheFavoritesOrder(animeIds);
    } on ApiException {
      rethrow;
    }
  }

  /// Removes an anime from favorites.
  ///
  /// [animeId] - The unique identifier of the anime to remove
  Future<void> removeFromFavorites(String animeId) async {
    try {
      await _dioClient.patch<void>(
        '/me/follow/$animeId',
        data: {'is_favorite': false},
      );

      // Update local cache
      await _cacheService.removeCachedUserFollow(animeId);
    } on ApiException {
      rethrow;
    }
  }

  /// Gets cached favorites order for offline access.
  ///
  /// Returns null if no cached data exists.
  Future<List<String>?> getCachedFavoritesOrder() async {
    final follows = await _cacheService.getCachedUserFollows();
    if (follows == null) return null;

    // Filter to only favorites and return their IDs
    return follows.where((f) => f.isFavorite).map((f) => f.animeId).toList();
  }

  /// Caches the favorites order locally.
  Future<void> _cacheFavoritesOrder(List<String> animeIds) async {
    // The order is implicitly stored in the user follows cache
    // We rely on the follow repository to maintain this
  }

  /// Applies a custom order to a list of favorites.
  ///
  /// [favorites] - The list of favorites to reorder
  /// [order] - The desired order as a list of anime IDs
  ///
  /// Returns the reordered list. Items not in the order list are appended at the end.
  List<FavoriteAnime> applyCustomOrder(
    List<FavoriteAnime> favorites,
    List<String> order,
  ) {
    if (order.isEmpty) return favorites;

    final orderMap = <String, int>{};
    for (var i = 0; i < order.length; i++) {
      orderMap[order[i]] = i;
    }

    final sorted = List<FavoriteAnime>.from(favorites);
    sorted.sort((a, b) {
      final aIndex = orderMap[a.anime.id] ?? order.length;
      final bIndex = orderMap[b.anime.id] ?? order.length;
      return aIndex.compareTo(bIndex);
    });

    return sorted;
  }
}
