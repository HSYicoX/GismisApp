import 'package:glados/glados.dart';

import 'package:gismis/features/schedule/data/schedule_repository.dart';
import 'package:gismis/shared/models/anime.dart';
import 'package:gismis/shared/models/schedule_entry.dart';
import 'package:gismis/shared/models/user_anime_follow.dart';

/// Feature: anime-tracker-app, Property 5: Followed Anime Priority
/// Validates: Requirements 2.3
///
/// For any schedule day containing both followed and unfollowed anime,
/// the sorted list SHALL place all followed anime before all unfollowed anime.

void main() {
  group('Property 5: Followed Anime Priority', () {
    // Helper to create an anime
    Anime createAnime({required String id, required String title}) {
      return Anime(
        id: id,
        title: title,
        titleAlias: [],
        coverUrl: 'https://example.com/cover.jpg',
        status: AnimeStatus.ongoing,
        updatedAt: DateTime(2024),
      );
    }

    // Helper to create a schedule entry
    ScheduleEntry createEntry({required String id, required bool isFollowed}) {
      return ScheduleEntry(
        anime: createAnime(id: id, title: 'Anime $id'),
        userFollow: isFollowed
            ? UserAnimeFollow(
                id: 'follow_$id',
                animeId: id,
                progressEpisode: 0,
                isFavorite: false,
              )
            : null,
        latestEpisode: 12,
      );
    }

    // Helper to find the index of first unfollowed anime
    int? findFirstUnfollowedIndex(List<ScheduleEntry> entries) {
      for (var i = 0; i < entries.length; i++) {
        if (entries[i].userFollow == null) {
          return i;
        }
      }
      return null;
    }

    // Helper to find the index of last followed anime
    int? findLastFollowedIndex(List<ScheduleEntry> entries) {
      for (var i = entries.length - 1; i >= 0; i--) {
        if (entries[i].userFollow != null) {
          return i;
        }
      }
      return null;
    }

    Glados2<int, int>(
      any.intInRange(1, 20),
      any.intInRange(1, 20),
    ).test('All followed anime appear before all unfollowed anime', (
      followedCount,
      unfollowedCount,
    ) {
      // Create mixed list with unfollowed first (worst case)
      final entries = <ScheduleEntry>[];

      for (var i = 0; i < unfollowedCount; i++) {
        entries.add(createEntry(id: 'unfollowed_$i', isFollowed: false));
      }
      for (var i = 0; i < followedCount; i++) {
        entries.add(createEntry(id: 'followed_$i', isFollowed: true));
      }

      final sorted = sortByFollowedFirst(entries);

      // Property: First unfollowed index > last followed index
      final firstUnfollowed = findFirstUnfollowedIndex(sorted);
      final lastFollowed = findLastFollowedIndex(sorted);

      if (firstUnfollowed != null && lastFollowed != null) {
        expect(
          lastFollowed < firstUnfollowed,
          isTrue,
          reason:
              'Last followed ($lastFollowed) should be before first unfollowed ($firstUnfollowed)',
        );
      }
    });

    Glados<int>(any.intInRange(1, 50)).test('Sorting preserves total count', (
      totalCount,
    ) {
      final entries = <ScheduleEntry>[];

      for (var i = 0; i < totalCount; i++) {
        entries.add(
          createEntry(
            id: 'anime_$i',
            isFollowed: i % 2 == 0, // Alternate followed/unfollowed
          ),
        );
      }

      final sorted = sortByFollowedFirst(entries);

      // Property: No entries lost
      expect(sorted.length, equals(totalCount));
    });

    Glados<int>(any.intInRange(1, 30)).test(
      'All followed anime are in the sorted result',
      (followedCount) {
        final entries = <ScheduleEntry>[];
        final followedIds = <String>{};

        for (var i = 0; i < followedCount; i++) {
          final id = 'followed_$i';
          entries.add(createEntry(id: id, isFollowed: true));
          followedIds.add(id);
        }

        // Add some unfollowed
        for (var i = 0; i < 5; i++) {
          entries.add(createEntry(id: 'unfollowed_$i', isFollowed: false));
        }

        final sorted = sortByFollowedFirst(entries);

        // Property: All followed anime are present
        final sortedFollowedIds = sorted
            .where((e) => e.userFollow != null)
            .map((e) => e.anime.id);

        expect(sortedFollowedIds.toSet(), equals(followedIds));
      },
    );

    Glados<int>(any.intInRange(1, 30)).test(
      'All unfollowed anime are in the sorted result',
      (unfollowedCount) {
        final entries = <ScheduleEntry>[];
        final unfollowedIds = <String>{};

        // Add some followed
        for (var i = 0; i < 5; i++) {
          entries.add(createEntry(id: 'followed_$i', isFollowed: true));
        }

        for (var i = 0; i < unfollowedCount; i++) {
          final id = 'unfollowed_$i';
          entries.add(createEntry(id: id, isFollowed: false));
          unfollowedIds.add(id);
        }

        final sorted = sortByFollowedFirst(entries);

        // Property: All unfollowed anime are present
        final sortedUnfollowedIds = sorted
            .where((e) => e.userFollow == null)
            .map((e) => e.anime.id);

        expect(sortedUnfollowedIds.toSet(), equals(unfollowedIds));
      },
    );

    test('Empty list returns empty list', () {
      final sorted = sortByFollowedFirst(<ScheduleEntry>[]);
      expect(sorted, isEmpty);
    });

    test('List with only followed anime returns same anime', () {
      final entries = [
        createEntry(id: '1', isFollowed: true),
        createEntry(id: '2', isFollowed: true),
        createEntry(id: '3', isFollowed: true),
      ];

      final sorted = sortByFollowedFirst(entries);

      expect(sorted.length, equals(3));
      expect(sorted.every((e) => e.userFollow != null), isTrue);
    });

    test('List with only unfollowed anime returns same anime', () {
      final entries = [
        createEntry(id: '1', isFollowed: false),
        createEntry(id: '2', isFollowed: false),
        createEntry(id: '3', isFollowed: false),
      ];

      final sorted = sortByFollowedFirst(entries);

      expect(sorted.length, equals(3));
      expect(sorted.every((e) => e.userFollow == null), isTrue);
    });

    test('Followed count in sorted list matches original', () {
      final entries = [
        createEntry(id: '1', isFollowed: true),
        createEntry(id: '2', isFollowed: false),
        createEntry(id: '3', isFollowed: true),
        createEntry(id: '4', isFollowed: false),
        createEntry(id: '5', isFollowed: true),
      ];

      final originalFollowedCount = entries
          .where((e) => e.userFollow != null)
          .length;

      final sorted = sortByFollowedFirst(entries);

      final sortedFollowedCount = sorted
          .where((e) => e.userFollow != null)
          .length;

      expect(sortedFollowedCount, equals(originalFollowedCount));
    });

    Glados<int>(any.intInRange(2, 20)).test(
      'First N entries are all followed when N followed anime exist',
      (followedCount) {
        final entries = <ScheduleEntry>[];

        // Mix followed and unfollowed
        for (var i = 0; i < followedCount; i++) {
          entries.add(createEntry(id: 'followed_$i', isFollowed: true));
        }
        for (var i = 0; i < 10; i++) {
          entries.add(createEntry(id: 'unfollowed_$i', isFollowed: false));
        }

        // Shuffle to randomize order
        entries.shuffle();

        final sorted = sortByFollowedFirst(entries);

        // Property: First followedCount entries are all followed
        for (var i = 0; i < followedCount; i++) {
          expect(
            sorted[i].userFollow != null,
            isTrue,
            reason: 'Entry at index $i should be followed',
          );
        }
      },
    );
  });
}
