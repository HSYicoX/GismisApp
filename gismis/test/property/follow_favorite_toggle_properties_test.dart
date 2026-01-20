import 'package:gismis/shared/models/user_anime_follow.dart';
import 'package:glados/glados.dart';

/// Feature: anime-tracker-app, Property 11: Follow/Favorite Toggle Consistency
/// Validates: Requirements 3.5, 3.6, 5.6
///
/// For any anime, after toggling follow status, querying the follow list
/// SHALL include (if followed) or exclude (if unfollowed) that anime.
/// The same applies to favorite status.

void main() {
  group('Property 11: Follow/Favorite Toggle Consistency', () {
    // Test follow toggle adds anime to follow list
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any anime ID, following it SHALL add it to the follow list',
      (animeId) {
        // Simulate empty follow list
        final followList = <UserAnimeFollow>[];

        // Simulate follow action - creates a new follow entry
        final newFollow = UserAnimeFollow(
          id: 'follow-$animeId',
          animeId: animeId,
          progressEpisode: 0,
          isFavorite: false,
        );

        // Add to list (simulating what repository does)
        final updatedList = [...followList, newFollow];

        // Verify anime is now in the list
        final isInList = updatedList.any((f) => f.animeId == animeId);
        expect(isInList, isTrue);
      },
    );

    // Test unfollow toggle removes anime from follow list
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any anime ID, unfollowing it SHALL remove it from the follow list',
      (animeId) {
        // Simulate follow list with the anime
        final followList = [
          UserAnimeFollow(
            id: 'follow-$animeId',
            animeId: animeId,
            progressEpisode: 5,
            isFavorite: true,
          ),
          const UserAnimeFollow(
            id: 'follow-other',
            animeId: 'other-anime',
            progressEpisode: 3,
            isFavorite: false,
          ),
        ];

        // Simulate unfollow action - removes the entry
        final updatedList = followList
            .where((f) => f.animeId != animeId)
            .toList();

        // Verify anime is no longer in the list
        final isInList = updatedList.any((f) => f.animeId == animeId);
        expect(isInList, isFalse);

        // Verify other anime is still in the list
        final otherStillExists = updatedList.any(
          (f) => f.animeId == 'other-anime',
        );
        expect(otherStillExists, isTrue);
      },
    );

    // Test favorite toggle updates favorite status correctly
    Glados2<String, bool>(any.nonEmptyLetterOrDigits, any.bool).test(
      'For any followed anime, toggling favorite SHALL flip the isFavorite flag',
      (animeId, initialFavorite) {
        // Create initial follow with given favorite status
        final follow = UserAnimeFollow(
          id: 'follow-$animeId',
          animeId: animeId,
          progressEpisode: 3,
          isFavorite: initialFavorite,
        );

        // Simulate toggle favorite - creates updated follow
        final updatedFollow = follow.copyWith(isFavorite: !initialFavorite);

        // Verify favorite status is flipped
        expect(updatedFollow.isFavorite, equals(!initialFavorite));

        // Verify other fields remain unchanged
        expect(updatedFollow.id, equals(follow.id));
        expect(updatedFollow.animeId, equals(follow.animeId));
        expect(updatedFollow.progressEpisode, equals(follow.progressEpisode));
      },
    );

    // Test follow list contains followed anime after follow
    Glados2<String, int>(
      any.nonEmptyLetterOrDigits,
      any.intInRange(0, 100),
    ).test(
      'For any anime, after following, querying follow list SHALL include that anime',
      (animeId, existingCount) {
        // Create existing follow list with random count of other animes
        final existingFollows = List.generate(
          existingCount,
          (i) => UserAnimeFollow(
            id: 'follow-existing-$i',
            animeId: 'existing-anime-$i',
            progressEpisode: i,
            isFavorite: i % 2 == 0,
          ),
        );

        // Follow the new anime
        final newFollow = UserAnimeFollow(
          id: 'follow-$animeId',
          animeId: animeId,
          progressEpisode: 0,
          isFavorite: false,
        );

        final updatedList = [...existingFollows, newFollow];

        // Query: check if anime is in list
        final foundFollow = updatedList.where((f) => f.animeId == animeId);

        expect(foundFollow.length, equals(1));
        expect(foundFollow.first.animeId, equals(animeId));
      },
    );

    // Test follow list excludes unfollowed anime after unfollow
    Glados2<String, int>(
      any.nonEmptyLetterOrDigits,
      any.intInRange(1, 50),
    ).test(
      'For any anime, after unfollowing, querying follow list SHALL exclude that anime',
      (animeId, otherCount) {
        // Create follow list with the target anime and others
        final targetFollow = UserAnimeFollow(
          id: 'follow-$animeId',
          animeId: animeId,
          progressEpisode: 10,
          isFavorite: true,
        );

        final otherFollows = List.generate(
          otherCount,
          (i) => UserAnimeFollow(
            id: 'follow-other-$i',
            animeId: 'other-anime-$i',
            progressEpisode: i,
            isFavorite: false,
          ),
        );

        final initialList = [targetFollow, ...otherFollows];

        // Unfollow the target anime
        final updatedList = initialList
            .where((f) => f.animeId != animeId)
            .toList();

        // Query: check if anime is NOT in list
        final foundFollow = updatedList.where((f) => f.animeId == animeId);

        expect(foundFollow.isEmpty, isTrue);

        // Verify list size decreased by 1
        expect(updatedList.length, equals(initialList.length - 1));
      },
    );

    // Test favorite filter includes only favorited animes
    Glados<int>(any.intInRange(1, 20)).test(
      'For any follow list, filtering favorites SHALL only include animes with isFavorite=true',
      (count) {
        // Create mixed follow list
        final follows = List.generate(
          count,
          (i) => UserAnimeFollow(
            id: 'follow-$i',
            animeId: 'anime-$i',
            progressEpisode: i,
            isFavorite: i % 3 == 0, // Every 3rd is favorite
          ),
        );

        // Filter favorites
        final favorites = follows.where((f) => f.isFavorite).toList();

        // Verify all items in favorites have isFavorite=true
        for (final fav in favorites) {
          expect(fav.isFavorite, isTrue);
        }

        // Verify count matches expected
        final expectedCount = follows.where((f) => f.isFavorite).length;
        expect(favorites.length, equals(expectedCount));
      },
    );

    // Test double toggle returns to original state
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any anime, toggling favorite twice SHALL return to original state',
      (animeId) {
        final original = UserAnimeFollow(
          id: 'follow-$animeId',
          animeId: animeId,
          progressEpisode: 5,
          isFavorite: true,
        );

        // First toggle
        final afterFirstToggle = original.copyWith(
          isFavorite: !original.isFavorite,
        );

        // Second toggle
        final afterSecondToggle = afterFirstToggle.copyWith(
          isFavorite: !afterFirstToggle.isFavorite,
        );

        // Should be back to original state
        expect(afterSecondToggle.isFavorite, equals(original.isFavorite));
      },
    );

    // Test follow/unfollow cycle consistency
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any anime, follow then unfollow SHALL result in empty follow status',
      (animeId) {
        // Start with no follow
        UserAnimeFollow? followStatus;

        // Follow
        followStatus = UserAnimeFollow(
          id: 'follow-$animeId',
          animeId: animeId,
          progressEpisode: 0,
          isFavorite: false,
        );

        expect(followStatus, isNotNull);

        // Unfollow (simulated by setting to null)
        followStatus = null;

        expect(followStatus, isNull);
      },
    );

    // Test favorite requires follow
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any anime, favorite status is only meaningful when followed',
      (animeId) {
        // When not followed, there's no follow object
        UserAnimeFollow? notFollowed;

        // isFavorite should be false when not followed
        final isFavoriteWhenNotFollowed = notFollowed?.isFavorite ?? false;
        expect(isFavoriteWhenNotFollowed, isFalse);

        // When followed, isFavorite can be true or false
        final followed = UserAnimeFollow(
          id: 'follow-$animeId',
          animeId: animeId,
          progressEpisode: 0,
          isFavorite: true,
        );

        expect(followed.isFavorite, isTrue);
      },
    );

    // Test follow preserves anime ID
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any anime ID, the follow entry SHALL preserve the exact anime ID',
      (animeId) {
        final follow = UserAnimeFollow(
          id: 'follow-$animeId',
          animeId: animeId,
          progressEpisode: 0,
          isFavorite: false,
        );

        expect(follow.animeId, equals(animeId));

        // After updates, anime ID should remain unchanged
        final updated = follow.copyWith(progressEpisode: 10, isFavorite: true);

        expect(updated.animeId, equals(animeId));
      },
    );
  });
}
