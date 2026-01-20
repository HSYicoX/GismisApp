import 'package:glados/glados.dart';

import 'package:gismis/shared/models/anime.dart';
import 'package:gismis/features/home/data/anime_repository.dart';

/// Feature: anime-tracker-app, Property 3: Pagination Accumulation
/// Validates: Requirements 1.2
///
/// For any sequence of paginated API responses, appending page N+1 results
/// to existing results SHALL produce a list containing all items from pages
/// 1 through N+1 without duplicates.

void main() {
  group('Property 3: Pagination Accumulation', () {
    // Helper to create an anime with given id
    Anime createAnime(String id) {
      return Anime(
        id: id,
        title: 'Anime $id',
        titleAlias: [],
        coverUrl: 'https://example.com/cover.jpg',
        status: AnimeStatus.ongoing,
        updatedAt: DateTime(2024),
      );
    }

    Glados<int>(any.intInRange(1, 20)).test(
      'For any number of pages, accumulation contains all items without duplicates',
      (pageCount) {
        // Simulate paginated results
        final allPages = <List<Anime>>[];
        for (var page = 1; page <= pageCount; page++) {
          final pageItems = List.generate(
            5,
            (i) => createAnime('page${page}_item$i'),
          );
          allPages.add(pageItems);
        }

        // Accumulate all pages
        var accumulated = <Anime>[];
        for (final page in allPages) {
          accumulated = accumulatePaginatedResults(accumulated, page);
        }

        // Property 1: Total count equals sum of all page items
        final expectedCount = pageCount * 5;
        expect(accumulated.length, equals(expectedCount));

        // Property 2: All items from all pages are present
        for (var page = 1; page <= pageCount; page++) {
          for (var i = 0; i < 5; i++) {
            final expectedId = 'page${page}_item$i';
            expect(
              accumulated.any((a) => a.id == expectedId),
              isTrue,
              reason: 'Item $expectedId should be in accumulated results',
            );
          }
        }

        // Property 3: No duplicates
        final ids = accumulated.map((a) => a.id).toSet();
        expect(ids.length, equals(accumulated.length));
      },
    );

    test('Accumulating empty page to existing results preserves existing', () {
      final existing = [createAnime('1'), createAnime('2'), createAnime('3')];

      final result = accumulatePaginatedResults(existing, []);

      expect(result.length, equals(3));
      expect(result.map((a) => a.id).toList(), equals(['1', '2', '3']));
    });

    test('Accumulating to empty list returns new items', () {
      final newItems = [createAnime('a'), createAnime('b')];

      final result = accumulatePaginatedResults([], newItems);

      expect(result.length, equals(2));
      expect(result.map((a) => a.id).toList(), equals(['a', 'b']));
    });

    Glados<int>(any.intInRange(1, 10)).test(
      'Duplicate items in new page are filtered out',
      (existingCount) {
        // Create existing items
        final existing = List.generate(
          existingCount,
          (i) => createAnime('item$i'),
        );

        // Create new page with some duplicates and some new items
        final newItems = [
          createAnime('item0'), // duplicate
          createAnime('new1'), // new
          createAnime('item1'), // duplicate (if exists)
          createAnime('new2'), // new
        ];

        final result = accumulatePaginatedResults(existing, newItems);

        // Should have existing items + only the new unique items
        final expectedNewCount = existingCount >= 2
            ? 2
            : (existingCount >= 1 ? 3 : 4);
        expect(result.length, equals(existingCount + expectedNewCount));

        // No duplicates
        final ids = result.map((a) => a.id).toSet();
        expect(ids.length, equals(result.length));
      },
    );

    test('Order is preserved: existing items first, then new items', () {
      final existing = [createAnime('a'), createAnime('b')];

      final newItems = [createAnime('c'), createAnime('d')];

      final result = accumulatePaginatedResults(existing, newItems);

      expect(result.length, equals(4));
      expect(result[0].id, equals('a'));
      expect(result[1].id, equals('b'));
      expect(result[2].id, equals('c'));
      expect(result[3].id, equals('d'));
    });

    Glados2<int, int>(
      any.intInRange(1, 10),
      any.intInRange(1, 10),
    ).test('For any two page sizes, accumulation is associative', (
      size1,
      size2,
    ) {
      final page1 = List.generate(size1, (i) => createAnime('p1_$i'));
      final page2 = List.generate(size2, (i) => createAnime('p2_$i'));
      final page3 = List.generate(3, (i) => createAnime('p3_$i'));

      // Accumulate (page1 + page2) + page3
      final result1 = accumulatePaginatedResults(
        accumulatePaginatedResults(page1, page2),
        page3,
      );

      // Accumulate page1 + (page2 + page3)
      final result2 = accumulatePaginatedResults(
        page1,
        accumulatePaginatedResults(page2, page3),
      );

      // Both should have same items (order may differ due to duplicate handling)
      expect(result1.length, equals(result2.length));

      final ids1 = result1.map((a) => a.id).toSet();
      final ids2 = result2.map((a) => a.id).toSet();
      expect(ids1, equals(ids2));
    });

    test('Accumulating same page twice does not create duplicates', () {
      final page = [createAnime('1'), createAnime('2'), createAnime('3')];

      var result = accumulatePaginatedResults([], page);
      result = accumulatePaginatedResults(result, page);

      expect(result.length, equals(3));
    });

    Glados<int>(any.intInRange(1, 50)).test(
      'For any list size, accumulating preserves all unique IDs',
      (size) {
        final items = List.generate(size, (i) => createAnime('unique_$i'));

        final result = accumulatePaginatedResults([], items);

        expect(result.length, equals(size));

        // All IDs are present
        for (var i = 0; i < size; i++) {
          expect(result.any((a) => a.id == 'unique_$i'), isTrue);
        }
      },
    );
  });
}
