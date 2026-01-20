import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/hive_cache.dart';
import '../../../shared/models/user_anime_follow.dart';

/// Repository for managing user's anime follow relationships.
///
/// Handles follow/unfollow operations and favorite management.
/// Syncs with backend and updates local cache.
class FollowRepository {
  FollowRepository({
    required DioClient dioClient,
    required CacheService cacheService,
  }) : _dioClient = dioClient,
       _cacheService = cacheService;
  final DioClient _dioClient;
  final CacheService _cacheService;

  /// Follows an anime.
  ///
  /// [animeId] - The unique identifier of the anime to follow
  ///
  /// Returns the created [UserAnimeFollow] object.
  Future<UserAnimeFollow> followAnime(String animeId) async {
    try {
      final response = await _dioClient.post<Map<String, dynamic>>(
        '/me/follow',
        data: {'anime_id': animeId},
      );

      final follow = UserAnimeFollow.fromJson(response.data!);

      // Update local cache
      await _cacheService.cacheUserFollow(follow);
      await _refreshFollowListCache();

      return follow;
    } on ApiException {
      rethrow;
    }
  }

  /// Unfollows an anime.
  ///
  /// [animeId] - The unique identifier of the anime to unfollow
  Future<void> unfollowAnime(String animeId) async {
    try {
      await _dioClient.delete<void>('/me/follow/$animeId');

      // Remove from local cache
      await _cacheService.removeCachedUserFollow(animeId);
      await _refreshFollowListCache();
    } on ApiException {
      rethrow;
    }
  }

  /// Updates the favorite status of a followed anime.
  ///
  /// [animeId] - The unique identifier of the anime
  /// [isFavorite] - The new favorite status
  ///
  /// Returns the updated [UserAnimeFollow] object.
  Future<UserAnimeFollow> updateFavorite(
    String animeId, {
    required bool isFavorite,
  }) async {
    try {
      final response = await _dioClient.patch<Map<String, dynamic>>(
        '/me/follow/$animeId',
        data: {'is_favorite': isFavorite},
      );

      final follow = UserAnimeFollow.fromJson(response.data!);

      // Update local cache
      await _cacheService.cacheUserFollow(follow);
      await _refreshFollowListCache();

      return follow;
    } on ApiException {
      rethrow;
    }
  }

  /// Updates the progress episode of a followed anime.
  ///
  /// [animeId] - The unique identifier of the anime
  /// [progressEpisode] - The new progress episode number
  ///
  /// Returns the updated [UserAnimeFollow] object.
  Future<UserAnimeFollow> updateProgress(
    String animeId, {
    required int progressEpisode,
  }) async {
    try {
      final response = await _dioClient.patch<Map<String, dynamic>>(
        '/me/follow/$animeId',
        data: {'progress_episode': progressEpisode},
      );

      final follow = UserAnimeFollow.fromJson(response.data!);

      // Update local cache
      await _cacheService.cacheUserFollow(follow);
      await _refreshFollowListCache();

      return follow;
    } on ApiException {
      rethrow;
    }
  }

  /// Gets the follow status for a specific anime.
  ///
  /// [animeId] - The unique identifier of the anime
  ///
  /// Returns [UserAnimeFollow] if the anime is followed, null otherwise.
  Future<UserAnimeFollow?> getFollowStatus(String animeId) async {
    // Try cache first
    final cached = await _cacheService.getCachedUserFollow(animeId);
    if (cached != null) {
      return cached;
    }

    // Fetch from network
    try {
      final follows = await getFollowedAnimes();
      return follows.where((f) => f.animeId == animeId).firstOrNull;
    } on ApiException {
      return null;
    }
  }

  /// Gets all followed animes for the current user.
  ///
  /// Returns a list of [UserAnimeFollow] objects.
  Future<List<UserAnimeFollow>> getFollowedAnimes() async {
    try {
      final response = await _dioClient.get<Map<String, dynamic>>('/me/follow');

      final data = response.data!;
      final itemsJson = data['items'] as List<dynamic>? ?? [];

      final follows = itemsJson
          .map((json) => UserAnimeFollow.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache the results
      await _cacheService.cacheUserFollows(follows);

      return follows;
    } on ApiException {
      rethrow;
    }
  }

  /// Gets cached follow list for offline access.
  ///
  /// Returns null if no cached data exists.
  Future<List<UserAnimeFollow>?> getCachedFollows() async {
    return _cacheService.getCachedUserFollows();
  }

  /// Gets cached follow status for a specific anime.
  ///
  /// Returns null if no cached data exists.
  Future<UserAnimeFollow?> getCachedFollowStatus(String animeId) async {
    return _cacheService.getCachedUserFollow(animeId);
  }

  /// Refreshes the follow list cache from network.
  Future<void> _refreshFollowListCache() async {
    try {
      await getFollowedAnimes();
    } catch (_) {
      // Silently ignore refresh errors
    }
  }

  /// Checks if an anime is followed (from cache).
  Future<bool> isFollowed(String animeId) async {
    final follow = await _cacheService.getCachedUserFollow(animeId);
    return follow != null;
  }

  /// Checks if an anime is favorited (from cache).
  Future<bool> isFavorite(String animeId) async {
    final follow = await _cacheService.getCachedUserFollow(animeId);
    return follow?.isFavorite ?? false;
  }
}
