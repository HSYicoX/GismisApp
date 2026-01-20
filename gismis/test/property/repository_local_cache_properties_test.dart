import 'dart:io';

import 'package:glados/glados.dart';
import 'package:hive/hive.dart';

import 'package:gismis/core/storage/hive_cache.dart';
import 'package:gismis/shared/models/anime.dart';

/// Feature: realtime-data-aggregation, Property: Local Cache Consistency
/// Validates: Requirements 9.3, 9.4
///
/// For any anime data fetched from Edge Functions, the local cache SHALL
/// store the data correctly, and when network is unavailable, the cached
/// data SHALL be retrievable.
///
/// This property test validates that:
/// 1. Data cached via CacheService can be retrieved correctly (round-trip)
/// 2. Cached data is available for offline use
/// 3. Cache operations are idempotent

void main() {
  late CacheService cacheService;
  late Directory tempDir;

  setUp(() async {
    // Create a temporary directory for Hive
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    cacheService = CacheService();
    await cacheService.initialize();
  });

  tearDown(() async {
    await cacheService.clearCache();
    await cacheService.dispose();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Property: Local Cache Consistency', () {
    // Test anime list cache round-trip (simulating Edge Function response)
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any anime list from Edge Function, caching then retrieving produces equivalent list',
      (id, title) async {
        // Simulate anime data from Edge Function (AnimeInfo format converted to Anime)
        final animeList = [
          Anime(
            id: id,
            title: title,
            titleAlias: ['alias1', 'alias2'],
            coverUrl: 'https://example.com/cover.jpg',
            summary: 'Test summary from Edge Function',
            status: AnimeStatus.ongoing,
            updatedAt: DateTime.now(),
          ),
          Anime(
            id: '${id}_2',
            title: '${title}_2',
            titleAlias: [],
            coverUrl: 'https://example.com/cover2.jpg',
            status: AnimeStatus.completed,
            updatedAt: DateTime.now(),
          ),
        ];

        // Cache the list (simulating what AnimeRepository does after Edge Function call)
        await cacheService.cacheAnimeList(animeList);

        // Retrieve from cache (simulating offline access)
        final cachedList = await cacheService.getCachedAnimeList();

        // Verify round-trip produces equivalent data
        expect(cachedList, isNotNull);
        expect(cachedList!.length, equals(animeList.length));
        for (var i = 0; i < animeList.length; i++) {
          expect(cachedList[i].id, equals(animeList[i].id));
          expect(cachedList[i].title, equals(animeList[i].title));
          expect(cachedList[i].coverUrl, equals(animeList[i].coverUrl));
          expect(cachedList[i].status, equals(animeList[i].status));
        }
      },
    );

    // Test cache availability for offline use
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any cached anime list, data SHALL be available for offline use',
      (id) async {
        // Clear cache first to ensure clean state
        await cacheService.clearCache();

        // Cache some data (simulating successful Edge Function call)
        await cacheService.cacheAnimeList([
          Anime(
            id: id,
            title: 'Test Anime',
            titleAlias: [],
            coverUrl: 'https://example.com/cover.jpg',
            status: AnimeStatus.ongoing,
            updatedAt: DateTime.now(),
          ),
        ]);

        // Verify cache exists (for offline access)
        expect(await cacheService.hasAnimeListCache(), isTrue);

        // Verify data can be retrieved (simulating offline scenario)
        final cachedList = await cacheService.getCachedAnimeList();
        expect(cachedList, isNotNull);
        expect(cachedList!.isNotEmpty, isTrue);
        expect(cachedList[0].id, equals(id));
      },
    );

    // Test cache update idempotency
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any anime list, caching the same data multiple times SHALL produce consistent results',
      (id) async {
        final animeList = [
          Anime(
            id: id,
            title: 'Test Anime',
            titleAlias: ['Alias'],
            coverUrl: 'https://example.com/cover.jpg',
            status: AnimeStatus.ongoing,
            updatedAt: DateTime.now(),
          ),
        ];

        // Cache the same data multiple times
        await cacheService.cacheAnimeList(animeList);
        await cacheService.cacheAnimeList(animeList);
        await cacheService.cacheAnimeList(animeList);

        // Verify data is consistent
        final cachedList = await cacheService.getCachedAnimeList();
        expect(cachedList, isNotNull);
        expect(cachedList!.length, equals(1));
        expect(cachedList[0].id, equals(id));
      },
    );

    // Test cache update with fresh data
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any cached data, updating with fresh data SHALL replace old data',
      (id) async {
        // Initial cache (simulating first Edge Function call)
        final initialList = [
          Anime(
            id: id,
            title: 'Initial Title',
            titleAlias: [],
            coverUrl: 'https://example.com/cover.jpg',
            status: AnimeStatus.ongoing,
            updatedAt: DateTime(2024),
          ),
        ];
        await cacheService.cacheAnimeList(initialList);

        // Update with fresh data (simulating forceRefresh Edge Function call)
        final updatedList = [
          Anime(
            id: id,
            title: 'Updated Title',
            titleAlias: ['New Alias'],
            coverUrl: 'https://example.com/new-cover.jpg',
            status: AnimeStatus.completed,
            updatedAt: DateTime(2024, 6),
          ),
        ];
        await cacheService.cacheAnimeList(updatedList);

        // Verify cache contains updated data
        final cachedList = await cacheService.getCachedAnimeList();
        expect(cachedList, isNotNull);
        expect(cachedList!.length, equals(1));
        expect(cachedList[0].title, equals('Updated Title'));
        expect(cachedList[0].status, equals(AnimeStatus.completed));
      },
    );

    // Test cache staleness check
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any cached data, staleness check SHALL work correctly',
      (id) async {
        await cacheService.cacheAnimeList([
          Anime(
            id: id,
            title: 'Test',
            titleAlias: [],
            coverUrl: 'https://example.com/cover.jpg',
            status: AnimeStatus.ongoing,
            updatedAt: DateTime.now(),
          ),
        ]);

        // Cache should not be stale with a long duration
        expect(
          await cacheService.isCacheStale(
            'anime_list',
            const Duration(hours: 24),
          ),
          isFalse,
        );

        // Cache should be stale with zero duration
        expect(
          await cacheService.isCacheStale('anime_list', Duration.zero),
          isTrue,
        );
      },
    );

    // Test empty cache returns null (for offline fallback logic)
    test('Empty cache returns null for anime list', () async {
      await cacheService.clearCache();
      final result = await cacheService.getCachedAnimeList();
      expect(result, isNull);
    });

    // Test cache with various anime statuses
    Glados<int>(any.intInRange(0, 3)).test(
      'For any anime status, cache SHALL preserve status correctly',
      (statusIndex) async {
        final statuses = [
          AnimeStatus.ongoing,
          AnimeStatus.completed,
          AnimeStatus.upcoming,
          AnimeStatus.hiatus,
        ];
        final status = statuses[statusIndex];

        final animeList = [
          Anime(
            id: 'test-$statusIndex',
            title: 'Test Anime',
            titleAlias: [],
            coverUrl: 'https://example.com/cover.jpg',
            status: status,
            updatedAt: DateTime.now(),
          ),
        ];

        await cacheService.cacheAnimeList(animeList);
        final cachedList = await cacheService.getCachedAnimeList();

        expect(cachedList, isNotNull);
        expect(cachedList![0].status, equals(status));
      },
    );

    // Test cache with multiple aliases (from Edge Function titleAliases)
    Glados<int>(any.intInRange(0, 5)).test(
      'For any number of title aliases, cache SHALL preserve all aliases',
      (aliasCount) async {
        final aliases = List.generate(aliasCount, (i) => 'Alias $i');

        final animeList = [
          Anime(
            id: 'test-aliases',
            title: 'Test Anime',
            titleAlias: aliases,
            coverUrl: 'https://example.com/cover.jpg',
            status: AnimeStatus.ongoing,
            updatedAt: DateTime.now(),
          ),
        ];

        await cacheService.cacheAnimeList(animeList);
        final cachedList = await cacheService.getCachedAnimeList();

        expect(cachedList, isNotNull);
        expect(cachedList![0].titleAlias.length, equals(aliasCount));
        for (var i = 0; i < aliasCount; i++) {
          expect(cachedList[0].titleAlias[i], equals('Alias $i'));
        }
      },
    );

    // Test cache clear
    test('Clearing cache removes all data', () async {
      // Add some data
      await cacheService.cacheAnimeList([
        Anime(
          id: 'test',
          title: 'Test',
          titleAlias: [],
          coverUrl: 'https://example.com/cover.jpg',
          status: AnimeStatus.ongoing,
          updatedAt: DateTime.now(),
        ),
      ]);

      // Verify data exists
      expect(await cacheService.hasAnimeListCache(), isTrue);

      // Clear cache
      await cacheService.clearCache();

      // Verify data is gone
      expect(await cacheService.hasAnimeListCache(), isFalse);
    });
  });
}
