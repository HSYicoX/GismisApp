import 'package:glados/glados.dart';

import 'package:gismis/features/schedule/data/schedule_repository.dart';
import 'package:gismis/shared/models/anime.dart';
import 'package:gismis/shared/models/schedule_entry.dart';
import 'package:gismis/shared/models/user_anime_follow.dart';

/// Feature: anime-tracker-app, Property 4: Schedule Weekday Grouping
/// Validates: Requirements 2.1, 2.2
///
/// For any list of ScheduleEntry objects, grouping by weekday SHALL produce
/// exactly 7 groups (Monday-Sunday), and each anime SHALL appear only in the
/// group matching its weekday value (or override weekday if set).

void main() {
  group('Property 4: Schedule Weekday Grouping', () {
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

    // Helper to create a schedule entry with optional weekday override
    ScheduleEntry createEntry({
      required String id,
      required int baseWeekday,
      int? overrideWeekday,
      bool isFollowed = false,
    }) {
      return ScheduleEntry(
        anime: createAnime(id: id, title: 'Anime $id'),
        userFollow: isFollowed
            ? UserAnimeFollow(
                id: 'follow_$id',
                animeId: id,
                progressEpisode: 0,
                followWeekdayOverride: overrideWeekday,
                isFavorite: false,
              )
            : null,
        latestEpisode: 12,
      );
    }

    // Function to get effective weekday (respects override)
    int getEffectiveWeekday(ScheduleEntry entry, int baseWeekday) {
      return entry.userFollow?.followWeekdayOverride ?? baseWeekday;
    }

    test('Grouping produces exactly 7 groups (one for each weekday)', () {
      final entries = <ScheduleEntry>[];

      // Create entries for various weekdays
      for (var i = 1; i <= 7; i++) {
        entries.add(createEntry(id: 'anime_$i', baseWeekday: i));
      }

      final grouped = groupScheduleByWeekday(
        entries,
        (entry) => int.parse(entry.anime.id.split('_')[1]),
      );

      // Property: Exactly 7 groups exist
      expect(grouped.length, equals(7));

      // Property: All weekdays 1-7 are present as keys
      for (var i = 1; i <= 7; i++) {
        expect(grouped.containsKey(i), isTrue, reason: 'Missing weekday $i');
      }
    });

    Glados<int>(any.intInRange(1, 7)).test(
      'Each anime appears only in its assigned weekday group',
      (weekday) {
        final entries = [createEntry(id: 'test_anime', baseWeekday: weekday)];

        final grouped = groupScheduleByWeekday(entries, (_) => weekday);

        // Property: Anime appears in correct weekday
        expect(grouped[weekday]!.length, equals(1));
        expect(grouped[weekday]!.first.anime.id, equals('test_anime'));

        // Property: Anime does not appear in other weekdays
        for (var i = 1; i <= 7; i++) {
          if (i != weekday) {
            expect(
              grouped[i]!.any((e) => e.anime.id == 'test_anime'),
              isFalse,
              reason: 'Anime should not appear in weekday $i',
            );
          }
        }
      },
    );

    Glados2<int, int>(any.intInRange(1, 7), any.intInRange(1, 7)).test(
      'Override weekday takes precedence over base weekday',
      (baseWeekday, overrideWeekday) {
        final entry = createEntry(
          id: 'override_anime',
          baseWeekday: baseWeekday,
          overrideWeekday: overrideWeekday,
          isFollowed: true,
        );

        final grouped = groupScheduleByWeekday([
          entry,
        ], (e) => getEffectiveWeekday(e, baseWeekday));

        // Property: Anime appears in override weekday, not base weekday
        expect(grouped[overrideWeekday]!.length, equals(1));

        if (baseWeekday != overrideWeekday) {
          expect(grouped[baseWeekday]!.isEmpty, isTrue);
        }
      },
    );

    test('Empty entries list produces 7 empty groups', () {
      final grouped = groupScheduleByWeekday(<ScheduleEntry>[], (_) => 1);

      expect(grouped.length, equals(7));
      for (var i = 1; i <= 7; i++) {
        expect(grouped[i], isEmpty);
      }
    });

    test('Multiple anime on same weekday are grouped together', () {
      final entries = [
        createEntry(id: 'anime_1', baseWeekday: 3),
        createEntry(id: 'anime_2', baseWeekday: 3),
        createEntry(id: 'anime_3', baseWeekday: 3),
      ];

      final grouped = groupScheduleByWeekday(entries, (_) => 3);

      // Property: All anime on Wednesday (3) are in the same group
      expect(grouped[3]!.length, equals(3));

      // Property: Other days are empty
      for (var i = 1; i <= 7; i++) {
        if (i != 3) {
          expect(grouped[i], isEmpty);
        }
      }
    });

    test('Anime distributed across all weekdays are correctly grouped', () {
      final entries = <ScheduleEntry>[];
      final weekdayAssignments = <String, int>{};

      // Create 2 anime per weekday
      for (var day = 1; day <= 7; day++) {
        for (var j = 0; j < 2; j++) {
          final id = 'anime_${day}_$j';
          entries.add(createEntry(id: id, baseWeekday: day));
          weekdayAssignments[id] = day;
        }
      }

      final grouped = groupScheduleByWeekday(
        entries,
        (entry) => weekdayAssignments[entry.anime.id]!,
      );

      // Property: Each weekday has exactly 2 anime
      for (var i = 1; i <= 7; i++) {
        expect(
          grouped[i]!.length,
          equals(2),
          reason: 'Weekday $i should have 2 anime',
        );
      }

      // Property: Total count matches
      final totalGrouped = grouped.values.fold<int>(
        0,
        (sum, list) => sum + list.length,
      );
      expect(totalGrouped, equals(entries.length));
    });

    Glados<int>(any.intInRange(1, 100)).test(
      'Total entries after grouping equals original count',
      (count) {
        final entries = <ScheduleEntry>[];
        final weekdayAssignments = <String, int>{};

        for (var i = 0; i < count; i++) {
          final weekday = (i % 7) + 1;
          final id = 'anime_$i';
          entries.add(createEntry(id: id, baseWeekday: weekday));
          weekdayAssignments[id] = weekday;
        }

        final grouped = groupScheduleByWeekday(
          entries,
          (entry) => weekdayAssignments[entry.anime.id]!,
        );

        final totalGrouped = grouped.values.fold<int>(
          0,
          (sum, list) => sum + list.length,
        );

        // Property: No entries lost during grouping
        expect(totalGrouped, equals(count));
      },
    );
  });
}
