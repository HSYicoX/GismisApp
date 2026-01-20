import 'package:glados/glados.dart';

import 'package:gismis/features/schedule/data/models/schedule_item.dart';
import 'package:gismis/features/schedule/data/supabase_schedule_repository.dart';
import 'package:gismis/shared/models/anime.dart';

/// Feature: supabase-integration, Property 6: Schedule Weekday Grouping
/// Validates: Requirements 4.1
///
/// For any list of ScheduleItem objects, grouping by ISO weekday SHALL produce
/// exactly 7 groups (Monday=1 to Sunday=7), and each item SHALL appear only in
/// the group matching its ISO weekday value derived from day_of_week.

void main() {
  group('Property 6: Schedule Weekday Grouping (Supabase)', () {
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

    // Helper to create a schedule item with database day_of_week
    ScheduleItem createScheduleItem({
      required String id,
      required int dbDayOfWeek, // 0=Sunday, 1=Monday, ..., 6=Saturday
      String airTime = '20:00:00',
      bool isActive = true,
    }) {
      return ScheduleItem(
        id: id,
        animeId: 'anime_$id',
        dayOfWeek: dbDayOfWeek,
        airTime: airTime,
        timezone: 'Asia/Shanghai',
        anime: createAnime(id: 'anime_$id', title: 'Anime $id'),
        isActive: isActive,
      );
    }

    test('Grouping produces exactly 7 groups (one for each ISO weekday)', () {
      final items = <ScheduleItem>[];

      // Create items for all database days (0-6)
      for (var dbDay = 0; dbDay <= 6; dbDay++) {
        items.add(createScheduleItem(id: 'item_$dbDay', dbDayOfWeek: dbDay));
      }

      final grouped = groupScheduleByIsoWeekday(items);

      // Property: Exactly 7 groups exist
      expect(grouped.length, equals(7));

      // Property: All ISO weekdays 1-7 are present as keys
      for (var i = 1; i <= 7; i++) {
        expect(
          grouped.containsKey(i),
          isTrue,
          reason: 'Missing ISO weekday $i',
        );
      }
    });

    test('Empty items list produces 7 empty groups', () {
      final grouped = groupScheduleByIsoWeekday(<ScheduleItem>[]);

      expect(grouped.length, equals(7));
      for (var i = 1; i <= 7; i++) {
        expect(grouped[i], isEmpty, reason: 'ISO weekday $i should be empty');
      }
    });

    // Test database day_of_week to ISO weekday conversion
    Glados<int>(any.intInRange(0, 6)).test(
      'Database day_of_week correctly maps to ISO weekday',
      (dbDayOfWeek) {
        final item = createScheduleItem(
          id: 'test_item',
          dbDayOfWeek: dbDayOfWeek,
        );

        final grouped = groupScheduleByIsoWeekday([item]);

        // Calculate expected ISO weekday
        // DB: 0=Sunday, 1=Monday, ..., 6=Saturday
        // ISO: 1=Monday, 2=Tuesday, ..., 7=Sunday
        final expectedIsoWeekday = dbDayOfWeek == 0 ? 7 : dbDayOfWeek;

        // Property: Item appears in correct ISO weekday group
        expect(
          grouped[expectedIsoWeekday]!.length,
          equals(1),
          reason: 'Item should be in ISO weekday $expectedIsoWeekday',
        );
        expect(grouped[expectedIsoWeekday]!.first.id, equals('test_item'));

        // Property: Item does not appear in other weekdays
        for (var i = 1; i <= 7; i++) {
          if (i != expectedIsoWeekday) {
            expect(
              grouped[i]!.any((e) => e.id == 'test_item'),
              isFalse,
              reason: 'Item should not appear in ISO weekday $i',
            );
          }
        }
      },
    );

    test('Sunday (db=0) maps to ISO weekday 7', () {
      final sundayItem = createScheduleItem(id: 'sunday', dbDayOfWeek: 0);
      final grouped = groupScheduleByIsoWeekday([sundayItem]);

      expect(grouped[7]!.length, equals(1));
      expect(grouped[7]!.first.id, equals('sunday'));

      // Verify not in other days
      for (var i = 1; i <= 6; i++) {
        expect(grouped[i], isEmpty);
      }
    });

    test('Monday (db=1) maps to ISO weekday 1', () {
      final mondayItem = createScheduleItem(id: 'monday', dbDayOfWeek: 1);
      final grouped = groupScheduleByIsoWeekday([mondayItem]);

      expect(grouped[1]!.length, equals(1));
      expect(grouped[1]!.first.id, equals('monday'));
    });

    test('Saturday (db=6) maps to ISO weekday 6', () {
      final saturdayItem = createScheduleItem(id: 'saturday', dbDayOfWeek: 6);
      final grouped = groupScheduleByIsoWeekday([saturdayItem]);

      expect(grouped[6]!.length, equals(1));
      expect(grouped[6]!.first.id, equals('saturday'));
    });

    test('Multiple items on same day are grouped together', () {
      final items = [
        createScheduleItem(id: 'item_1', dbDayOfWeek: 3, airTime: '18:00:00'),
        createScheduleItem(id: 'item_2', dbDayOfWeek: 3, airTime: '20:00:00'),
        createScheduleItem(id: 'item_3', dbDayOfWeek: 3, airTime: '22:00:00'),
      ];

      final grouped = groupScheduleByIsoWeekday(items);

      // DB day 3 = Wednesday = ISO weekday 3
      expect(grouped[3]!.length, equals(3));

      // Other days should be empty
      for (var i = 1; i <= 7; i++) {
        if (i != 3) {
          expect(grouped[i], isEmpty);
        }
      }
    });

    Glados<int>(
      any.intInRange(1, 100),
    ).test('Total items after grouping equals original count', (count) {
      final items = <ScheduleItem>[];

      for (var i = 0; i < count; i++) {
        final dbDayOfWeek = i % 7; // Distribute across all days
        items.add(createScheduleItem(id: 'item_$i', dbDayOfWeek: dbDayOfWeek));
      }

      final grouped = groupScheduleByIsoWeekday(items);

      final totalGrouped = grouped.values.fold<int>(
        0,
        (sum, list) => sum + list.length,
      );

      // Property: No items lost during grouping
      expect(totalGrouped, equals(count));
    });

    test('Items distributed across all days are correctly grouped', () {
      final items = <ScheduleItem>[];

      // Create 2 items per database day (0-6)
      for (var dbDay = 0; dbDay <= 6; dbDay++) {
        for (var j = 0; j < 2; j++) {
          items.add(
            createScheduleItem(id: 'item_${dbDay}_$j', dbDayOfWeek: dbDay),
          );
        }
      }

      final grouped = groupScheduleByIsoWeekday(items);

      // Each ISO weekday should have exactly 2 items
      for (var i = 1; i <= 7; i++) {
        expect(
          grouped[i]!.length,
          equals(2),
          reason: 'ISO weekday $i should have 2 items',
        );
      }

      // Total should be 14
      expect(grouped.totalItems, equals(14));
    });

    // Test the conversion functions
    group('Weekday conversion functions', () {
      test('isoWeekdayToDbDayOfWeek converts correctly', () {
        expect(isoWeekdayToDbDayOfWeek(1), equals(1)); // Monday
        expect(isoWeekdayToDbDayOfWeek(2), equals(2)); // Tuesday
        expect(isoWeekdayToDbDayOfWeek(3), equals(3)); // Wednesday
        expect(isoWeekdayToDbDayOfWeek(4), equals(4)); // Thursday
        expect(isoWeekdayToDbDayOfWeek(5), equals(5)); // Friday
        expect(isoWeekdayToDbDayOfWeek(6), equals(6)); // Saturday
        expect(isoWeekdayToDbDayOfWeek(7), equals(0)); // Sunday
      });

      test('dbDayOfWeekToIsoWeekday converts correctly', () {
        expect(dbDayOfWeekToIsoWeekday(0), equals(7)); // Sunday
        expect(dbDayOfWeekToIsoWeekday(1), equals(1)); // Monday
        expect(dbDayOfWeekToIsoWeekday(2), equals(2)); // Tuesday
        expect(dbDayOfWeekToIsoWeekday(3), equals(3)); // Wednesday
        expect(dbDayOfWeekToIsoWeekday(4), equals(4)); // Thursday
        expect(dbDayOfWeekToIsoWeekday(5), equals(5)); // Friday
        expect(dbDayOfWeekToIsoWeekday(6), equals(6)); // Saturday
      });

      Glados<int>(any.intInRange(1, 7)).test(
        'Round-trip: ISO -> DB -> ISO preserves value',
        (isoWeekday) {
          final dbDay = isoWeekdayToDbDayOfWeek(isoWeekday);
          final backToIso = dbDayOfWeekToIsoWeekday(dbDay);

          expect(backToIso, equals(isoWeekday));
        },
      );

      Glados<int>(any.intInRange(0, 6)).test(
        'Round-trip: DB -> ISO -> DB preserves value',
        (dbDayOfWeek) {
          final isoDay = dbDayOfWeekToIsoWeekday(dbDayOfWeek);
          final backToDb = isoWeekdayToDbDayOfWeek(isoDay);

          expect(backToDb, equals(dbDayOfWeek));
        },
      );
    });

    // Test sorting by air time
    group('Sort by air time', () {
      test('sortScheduleByAirTime sorts items within each day', () {
        final items = [
          createScheduleItem(id: 'late', dbDayOfWeek: 1, airTime: '22:00:00'),
          createScheduleItem(id: 'early', dbDayOfWeek: 1, airTime: '08:00:00'),
          createScheduleItem(id: 'mid', dbDayOfWeek: 1, airTime: '14:00:00'),
        ];

        final grouped = groupScheduleByIsoWeekday(items);
        final sorted = sortScheduleByAirTime(grouped);

        // Monday (ISO 1) should have items sorted by air time
        expect(sorted[1]!.length, equals(3));
        expect(sorted[1]![0].id, equals('early'));
        expect(sorted[1]![1].id, equals('mid'));
        expect(sorted[1]![2].id, equals('late'));
      });
    });

    // Test filtering active items
    group('Filter active items', () {
      test('filterActiveScheduleItems removes inactive items', () {
        final items = [
          createScheduleItem(id: 'active1', dbDayOfWeek: 1, isActive: true),
          createScheduleItem(id: 'inactive', dbDayOfWeek: 1, isActive: false),
          createScheduleItem(id: 'active2', dbDayOfWeek: 1, isActive: true),
        ];

        final filtered = filterActiveScheduleItems(items);

        expect(filtered.length, equals(2));
        expect(filtered.any((e) => e.id == 'inactive'), isFalse);
        expect(filtered.any((e) => e.id == 'active1'), isTrue);
        expect(filtered.any((e) => e.id == 'active2'), isTrue);
      });

      Glados<int>(any.intInRange(0, 50)).test(
        'Filtered count is always <= original count',
        (count) {
          final items = <ScheduleItem>[];

          for (var i = 0; i < count; i++) {
            items.add(
              createScheduleItem(
                id: 'item_$i',
                dbDayOfWeek: i % 7,
                isActive: i % 2 == 0, // Half active, half inactive
              ),
            );
          }

          final filtered = filterActiveScheduleItems(items);

          expect(filtered.length, lessThanOrEqualTo(count));
        },
      );
    });

    // Test WeeklySchedule extension methods
    group('WeeklySchedule extension', () {
      test('forWeekday returns items for specific day', () {
        final items = [
          createScheduleItem(id: 'mon1', dbDayOfWeek: 1),
          createScheduleItem(id: 'mon2', dbDayOfWeek: 1),
          createScheduleItem(id: 'tue1', dbDayOfWeek: 2),
        ];

        final grouped = groupScheduleByIsoWeekday(items);

        expect(grouped.forWeekday(1).length, equals(2));
        expect(grouped.forWeekday(2).length, equals(1));
        expect(grouped.forWeekday(3).length, equals(0));
      });

      test('totalItems returns correct count', () {
        final items = [
          createScheduleItem(id: 'item1', dbDayOfWeek: 1),
          createScheduleItem(id: 'item2', dbDayOfWeek: 3),
          createScheduleItem(id: 'item3', dbDayOfWeek: 5),
        ];

        final grouped = groupScheduleByIsoWeekday(items);

        expect(grouped.totalItems, equals(3));
      });

      test('hasNoItems returns true for schedule with no items', () {
        final grouped = groupScheduleByIsoWeekday(<ScheduleItem>[]);

        // The grouped map has 7 keys (one for each day), but all lists are empty
        // So hasNoItems should check if all lists are empty, not if the map is empty
        expect(grouped.hasNoItems, isTrue);
        expect(grouped.hasItems, isFalse);
        expect(grouped.totalItems, equals(0));
      });

      test('hasItems returns true for non-empty schedule', () {
        final items = [createScheduleItem(id: 'item1', dbDayOfWeek: 1)];
        final grouped = groupScheduleByIsoWeekday(items);

        expect(grouped.hasNoItems, isFalse);
        expect(grouped.hasItems, isTrue);
      });
    });
  });
}
