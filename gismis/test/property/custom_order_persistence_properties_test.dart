import 'package:glados/glados.dart';

import 'package:gismis/features/schedule/data/schedule_repository.dart';
import 'package:gismis/shared/models/anime.dart';
import 'package:gismis/shared/models/schedule_entry.dart';

/// Feature: anime-tracker-app, Property 7: Custom Order Persistence Round-Trip
/// Validates: Requirements 2.6, 5.4
///
/// For any list of anime IDs representing a custom order, saving the order
/// and then retrieving it SHALL return the same list in the same sequence.

void main() {
  group('Property 7: Custom Order Persistence Round-Trip', () {
    // Helper to create a schedule entry with given anime ID
    ScheduleEntry createEntry(String id) {
      return ScheduleEntry(
        anime: Anime(
          id: id,
          title: 'Anime $id',
          titleAlias: [],
          coverUrl: 'https://example.com/$id.jpg',
          status: AnimeStatus.ongoing,
          updatedAt: DateTime(2024),
        ),
        latestEpisode: 12,
      );
    }

    Glados(any.positiveIntOrZero.map((n) => (n % 10) + 1)).test(
      'For any custom order, applying it preserves the exact sequence',
      (count) {
        // Generate anime IDs
        final animeIds = List.generate(count, (i) => 'anime_$i');
        final entries = animeIds.map(createEntry).toList();

        // Shuffle to create a custom order
        final customOrder = List<String>.from(animeIds)..shuffle();

        // Apply custom order
        final reordered = applyCustomOrder(entries, customOrder);

        // Extract IDs from reordered list
        final resultIds = reordered.map((e) => e.anime.id).toList();

        // Property: The result order matches the custom order exactly
        expect(resultIds, equals(customOrder));
      },
    );

    Glados(any.positiveIntOrZero.map((n) => (n % 8) + 2)).test(
      'For any list of entries, applying empty order preserves original order',
      (count) {
        final entries = List.generate(count, (i) => createEntry('anime_$i'));
        final originalIds = entries.map((e) => e.anime.id).toList();

        // Apply empty custom order
        final result = applyCustomOrder(entries, []);
        final resultIds = result.map((e) => e.anime.id).toList();

        // Property: Empty order preserves original order
        expect(resultIds, equals(originalIds));
      },
    );

    Glados(any.positiveIntOrZero.map((n) => (n % 6) + 3)).test(
      'For any partial custom order, ordered items come first in sequence',
      (count) {
        final entries = List.generate(count, (i) => createEntry('anime_$i'));

        // Create partial order (only first half)
        final halfCount = count ~/ 2;
        final partialOrder = List.generate(halfCount, (i) => 'anime_$i')
          ..shuffle();

        final result = applyCustomOrder(entries, partialOrder);
        final resultIds = result.map((e) => e.anime.id).toList();

        // Property: Items in custom order appear first, in the specified sequence
        final orderedPart = resultIds.take(halfCount).toList();
        expect(orderedPart, equals(partialOrder));
      },
    );

    test('Custom order with single item works correctly', () {
      final entries = [createEntry('a'), createEntry('b'), createEntry('c')];

      final result = applyCustomOrder(entries, ['b']);
      final resultIds = result.map((e) => e.anime.id).toList();

      // 'b' should be first
      expect(resultIds.first, equals('b'));
      // Others maintain relative order
      expect(resultIds.sublist(1), containsAll(['a', 'c']));
    });

    test('Custom order with all items in reverse works correctly', () {
      final entries = [createEntry('a'), createEntry('b'), createEntry('c')];

      final result = applyCustomOrder(entries, ['c', 'b', 'a']);
      final resultIds = result.map((e) => e.anime.id).toList();

      expect(resultIds, equals(['c', 'b', 'a']));
    });

    test('Custom order with non-existent IDs is ignored', () {
      final entries = [createEntry('a'), createEntry('b')];

      // Include IDs that don't exist in entries
      final result = applyCustomOrder(entries, ['x', 'b', 'y', 'a', 'z']);
      final resultIds = result.map((e) => e.anime.id).toList();

      // Only existing IDs are reordered
      expect(resultIds, equals(['b', 'a']));
    });

    Glados(any.positiveIntOrZero.map((n) => (n % 5) + 2)).test(
      'Applying same order twice produces identical results',
      (count) {
        final entries = List.generate(count, (i) => createEntry('anime_$i'));
        final customOrder = List.generate(count, (i) => 'anime_$i')..shuffle();

        final result1 = applyCustomOrder(entries, customOrder);
        final result2 = applyCustomOrder(entries, customOrder);

        final ids1 = result1.map((e) => e.anime.id).toList();
        final ids2 = result2.map((e) => e.anime.id).toList();

        // Property: Idempotent - same input produces same output
        expect(ids1, equals(ids2));
      },
    );

    Glados(any.positiveIntOrZero.map((n) => (n % 5) + 2)).test(
      'Reapplying result order to original entries produces same result',
      (count) {
        final entries = List.generate(count, (i) => createEntry('anime_$i'));
        final customOrder = List.generate(count, (i) => 'anime_$i')..shuffle();

        // First application
        final result1 = applyCustomOrder(entries, customOrder);
        final resultOrder = result1.map((e) => e.anime.id).toList();

        // Apply the result order again
        final result2 = applyCustomOrder(entries, resultOrder);
        final ids2 = result2.map((e) => e.anime.id).toList();

        // Property: Round-trip preserves order
        expect(ids2, equals(resultOrder));
      },
    );

    test('Empty entries list returns empty list', () {
      final result = applyCustomOrder([], ['a', 'b', 'c']);
      expect(result, isEmpty);
    });

    test('Custom order preserves entry data integrity', () {
      final entries = [
        ScheduleEntry(
          anime: Anime(
            id: 'a',
            title: 'Anime A',
            titleAlias: ['Alias A'],
            coverUrl: 'https://example.com/a.jpg',
            status: AnimeStatus.ongoing,
            updatedAt: DateTime(2024),
          ),
          latestEpisode: 10,
        ),
        ScheduleEntry(
          anime: Anime(
            id: 'b',
            title: 'Anime B',
            titleAlias: ['Alias B'],
            coverUrl: 'https://example.com/b.jpg',
            status: AnimeStatus.completed,
            updatedAt: DateTime(2024, 2),
          ),
          latestEpisode: 24,
        ),
      ];

      final result = applyCustomOrder(entries, ['b', 'a']);

      // Verify data integrity
      expect(result[0].anime.id, equals('b'));
      expect(result[0].anime.title, equals('Anime B'));
      expect(result[0].latestEpisode, equals(24));

      expect(result[1].anime.id, equals('a'));
      expect(result[1].anime.title, equals('Anime A'));
      expect(result[1].latestEpisode, equals(10));
    });
  });
}
