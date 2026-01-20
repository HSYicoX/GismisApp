import 'dart:io';

import 'package:glados/glados.dart';
import 'package:hive/hive.dart';

import 'package:gismis/core/storage/hive_cache.dart';
import 'package:gismis/shared/models/anime.dart';
import 'package:gismis/shared/models/anime_detail.dart';
import 'package:gismis/shared/models/anime_platform.dart';
import 'package:gismis/shared/models/anime_schedule.dart';
import 'package:gismis/shared/models/anime_episode_state.dart';
import 'package:gismis/shared/models/user_anime_follow.dart';

/// Feature: anime-tracker-app, Property 15: Cache-First Display
/// Validates: Requirements 9.2
///
/// For any app launch with cached data, the UI SHALL display cached content
/// before network response arrives, and SHALL update when fresh data is received.
///
/// This property test validates that:
/// 1. Data cached via CacheService can be retrieved correctly (round-trip)
/// 2. Cached data is available immediately without network calls
/// 3. Cache timestamps are tracked for staleness checks

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

  group('Property 15: Cache-First Display', () {
    // Test anime list cache round-trip
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any anime list, caching then retrieving produces equivalent list',
      (id, title) async {
        final animeList = [
          Anime(
            id: id,
            title: title,
            titleAlias: ['alias1', 'alias2'],
            coverUrl: 'https://example.com/cover.jpg',
            summary: 'Test summary',
            status: AnimeStatus.ongoing,
            updatedAt: DateTime(2024, 1, 15, 10, 30),
          ),
          Anime(
            id: '${id}_2',
            title: '${title}_2',
            titleAlias: [],
            coverUrl: 'https://example.com/cover2.jpg',
            status: AnimeStatus.completed,
            updatedAt: DateTime(2024, 2, 20),
          ),
        ];

        // Cache the list
        await cacheService.cacheAnimeList(animeList);

        // Retrieve from cache (simulating app launch with cached data)
        final cachedList = await cacheService.getCachedAnimeList();

        // Verify round-trip produces equivalent data
        expect(cachedList, isNotNull);
        expect(cachedList!.length, equals(animeList.length));
        for (var i = 0; i < animeList.length; i++) {
          expect(cachedList[i], equals(animeList[i]));
        }
      },
    );

    // Test anime detail cache round-trip
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any anime detail, caching then retrieving produces equivalent object',
      (id) async {
        final detail = AnimeDetail(
          id: id,
          title: 'Test Anime',
          titleAlias: ['Alias 1'],
          coverUrl: 'https://example.com/cover.jpg',
          summary: 'Detailed summary',
          status: AnimeStatus.ongoing,
          updatedAt: DateTime(2024, 4),
          sourceType: 'manga',
          sourceTitle: 'Original Manga',
          platforms: const [
            AnimePlatform(
              platform: 'bilibili',
              url: 'https://bilibili.com/anime/123',
              region: 'CN',
            ),
          ],
          schedule: const AnimeSchedule(weekday: 5, updateTime: '22:00'),
          episodeState: AnimeEpisodeState(
            latestEpisode: 12,
            latestTitle: 'Episode 12',
            latestBrief: 'Final episode',
            lastCheckedAt: DateTime(2024, 4, 1, 22, 30),
          ),
        );

        // Cache the detail
        await cacheService.cacheAnimeDetail(id, detail);

        // Retrieve from cache
        final cachedDetail = await cacheService.getCachedAnimeDetail(id);

        // Verify round-trip
        expect(cachedDetail, isNotNull);
        expect(cachedDetail, equals(detail));
      },
    );

    // Test user follow cache round-trip
    Glados2<String, int>(
      any.nonEmptyLetterOrDigits,
      any.positiveIntOrZero,
    ).test(
      'For any user follows list, caching then retrieving produces equivalent list',
      (animeId, progress) async {
        final follows = [
          UserAnimeFollow(
            id: 'follow-1',
            animeId: animeId,
            progressEpisode: progress,
            followWeekdayOverride: 3,
            notes: 'My notes',
            isFavorite: true,
          ),
          UserAnimeFollow(
            id: 'follow-2',
            animeId: '${animeId}_2',
            progressEpisode: progress + 1,
            isFavorite: false,
          ),
        ];

        // Cache the follows
        await cacheService.cacheUserFollows(follows);

        // Retrieve from cache
        final cachedFollows = await cacheService.getCachedUserFollows();

        // Verify round-trip
        expect(cachedFollows, isNotNull);
        expect(cachedFollows!.length, equals(follows.length));
        for (var i = 0; i < follows.length; i++) {
          expect(cachedFollows[i], equals(follows[i]));
        }
      },
    );

    // Test cache availability check
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any cached anime list, hasAnimeListCache returns true after caching',
      (id) async {
        // Clear cache first to ensure clean state
        await cacheService.clearCache();

        // Cache some data
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

        // Now cache exists
        expect(await cacheService.hasAnimeListCache(), isTrue);
      },
    );

    // Test cache timestamp tracking
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any cached data, cache timestamp is recorded',
      (id) async {
        final beforeCache = DateTime.now();

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

        final afterCache = DateTime.now();
        final cacheTime = await cacheService.getAnimeListCacheTime();

        expect(cacheTime, isNotNull);
        expect(
          cacheTime!.isAfter(beforeCache.subtract(const Duration(seconds: 1))),
          isTrue,
        );
        expect(
          cacheTime.isBefore(afterCache.add(const Duration(seconds: 1))),
          isTrue,
        );
      },
    );

    // Test cache staleness check
    test('Cache staleness check works correctly', () async {
      await cacheService.cacheAnimeList([
        Anime(
          id: 'test-id',
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
    });

    // Test empty cache returns null
    test('Empty cache returns null for anime list', () async {
      final result = await cacheService.getCachedAnimeList();
      expect(result, isNull);
    });

    test('Empty cache returns null for anime detail', () async {
      final result = await cacheService.getCachedAnimeDetail('non-existent');
      expect(result, isNull);
    });

    // Test cache update (simulating fresh data received)
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any cached data, updating cache replaces old data',
      (id) async {
        // Initial cache
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

        // Update with fresh data
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

    // Test individual user follow cache
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any single user follow, caching and retrieving works correctly',
      (animeId) async {
        final follow = UserAnimeFollow(
          id: 'follow-single',
          animeId: animeId,
          progressEpisode: 5,
          isFavorite: true,
        );

        await cacheService.cacheUserFollow(follow);
        final cached = await cacheService.getCachedUserFollow(animeId);

        expect(cached, isNotNull);
        expect(cached, equals(follow));
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
      await cacheService.cacheAnimeDetail(
        'test',
        AnimeDetail(
          id: 'test',
          title: 'Test',
          titleAlias: [],
          coverUrl: 'https://example.com/cover.jpg',
          status: AnimeStatus.ongoing,
          updatedAt: DateTime.now(),
          platforms: const [],
        ),
      );

      // Verify data exists
      expect(await cacheService.hasAnimeListCache(), isTrue);
      expect(await cacheService.hasAnimeDetailCache('test'), isTrue);

      // Clear cache
      await cacheService.clearCache();

      // Verify data is gone
      expect(await cacheService.hasAnimeListCache(), isFalse);
      expect(await cacheService.hasAnimeDetailCache('test'), isFalse);
    });
  });
}
