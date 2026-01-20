import 'package:gismis/features/anime_library/data/models/models.dart';
import 'package:glados/glados.dart';

/// Feature: supabase-integration, Property 4: JSON Serialization Round-Trip
/// Validates: Requirements 3.1
///
/// For any AnimeLibraryItem, AnimeSeason, Episode, SourceMaterial, or Chapter
/// object, serializing to JSON and deserializing back SHALL produce an
/// equivalent object.

void main() {
  group('Property 4: JSON Model Serialization Round-Trip', () {
    // Test AnimeLibraryItem round-trip
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any AnimeLibraryItem, toJson then fromJson produces equivalent object',
      (id, title) {
        final anime = AnimeLibraryItem(
          id: id,
          title: title,
          titleJa: '日本語タイトル',
          synopsis: 'Test synopsis',
          coverUrl: 'https://example.com/cover.jpg',
          bannerUrl: 'https://example.com/banner.jpg',
          genres: ['action', 'adventure'],
          rating: 8.5,
          status: AnimeLibraryStatus.airing,
          startDate: DateTime(2024, 1, 15),
          endDate: DateTime(2024, 6, 30),
          seasonCount: 2,
          currentSeason: 1,
          createdAt: DateTime(2024, 1, 1, 10, 30),
          updatedAt: DateTime(2024, 6, 15, 14, 45),
        );

        final json = anime.toJson();
        final restored = AnimeLibraryItem.fromJson(json);

        expect(restored, equals(anime));
      },
    );

    // Test AnimeLibraryItem with null optional fields
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any AnimeLibraryItem with null fields, round-trip preserves nulls',
      (id) {
        final anime = AnimeLibraryItem(
          id: id,
          title: 'Test Title',
          status: AnimeLibraryStatus.upcoming,
        );

        final json = anime.toJson();
        final restored = AnimeLibraryItem.fromJson(json);

        expect(restored, equals(anime));
        expect(restored.titleJa, isNull);
        expect(restored.synopsis, isNull);
        expect(restored.coverUrl, isNull);
        expect(restored.rating, isNull);
      },
    );

    // Test all AnimeLibraryStatus values round-trip
    test(
      'All AnimeLibraryStatus values serialize and deserialize correctly',
      () {
        for (final status in AnimeLibraryStatus.values) {
          final anime = AnimeLibraryItem(
            id: 'test-id',
            title: 'Test',
            status: status,
          );

          final json = anime.toJson();
          final restored = AnimeLibraryItem.fromJson(json);

          expect(restored.status, equals(status));
        }
      },
    );

    // Test AnimeSeason round-trip
    Glados2<String, int>(
      any.nonEmptyLetterOrDigits,
      any.intInRange(1, 10),
    ).test(
      'For any AnimeSeason, toJson then fromJson produces equivalent object',
      (id, seasonNumber) {
        final season = AnimeSeason(
          id: id,
          animeId: 'anime-123',
          seasonNumber: seasonNumber,
          title: '第${seasonNumber}季',
          episodeCount: 12,
          latestEpisode: 8,
          status: AnimeSeasonStatus.airing,
          startDate: DateTime(2024, 4, 1),
          endDate: DateTime(2024, 6, 30),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 5, 20),
        );

        final json = season.toJson();
        final restored = AnimeSeason.fromJson(json);

        expect(restored, equals(season));
      },
    );

    // Test AnimeSeason with nested episodes
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any AnimeSeason with episodes, round-trip preserves nested data',
      (id) {
        final episodes = [
          Episode(
            id: 'ep-1',
            seasonId: id,
            episodeNumber: 1,
            title: 'Episode 1',
            duration: const Duration(minutes: 24),
            airDate: DateTime(2024, 4, 1),
          ),
          Episode(
            id: 'ep-2',
            seasonId: id,
            episodeNumber: 2,
            title: 'Episode 2',
            duration: const Duration(minutes: 24),
            airDate: DateTime(2024, 4, 8),
          ),
        ];

        final season = AnimeSeason(
          id: id,
          animeId: 'anime-123',
          seasonNumber: 1,
          episodeCount: 2,
          status: AnimeSeasonStatus.completed,
          episodes: episodes,
        );

        final json = season.toJson();
        final restored = AnimeSeason.fromJson(json);

        expect(restored, equals(season));
        expect(restored.episodes, isNotNull);
        expect(restored.episodes!.length, equals(2));
      },
    );

    // Test all AnimeSeasonStatus values round-trip
    test(
      'All AnimeSeasonStatus values serialize and deserialize correctly',
      () {
        for (final status in AnimeSeasonStatus.values) {
          final season = AnimeSeason(
            id: 'test-id',
            animeId: 'anime-123',
            seasonNumber: 1,
            status: status,
          );

          final json = season.toJson();
          final restored = AnimeSeason.fromJson(json);

          expect(restored.status, equals(status));
        }
      },
    );

    // Test Episode round-trip
    Glados2<String, int>(
      any.nonEmptyLetterOrDigits,
      any.intInRange(1, 100),
    ).test('For any Episode, toJson then fromJson produces equivalent object', (
      id,
      episodeNumber,
    ) {
      final episode = Episode(
        id: id,
        seasonId: 'season-123',
        episodeNumber: episodeNumber,
        title: 'Episode $episodeNumber',
        synopsis: 'Episode synopsis',
        duration: const Duration(minutes: 24, seconds: 30),
        airDate: DateTime(2024, 5, 15),
        thumbnailUrl: 'https://example.com/thumb.jpg',
        createdAt: DateTime(2024, 5, 10),
        updatedAt: DateTime(2024, 5, 15),
      );

      final json = episode.toJson();
      final restored = Episode.fromJson(json);

      expect(restored, equals(episode));
    });

    // Test Episode with platform links
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any Episode with platform links, round-trip preserves links',
      (id) {
        final episode = Episode(
          id: id,
          seasonId: 'season-123',
          episodeNumber: 1,
          platformLinks: {
            'bilibili': 'https://bilibili.com/ep/123',
            'iqiyi': 'https://iqiyi.com/ep/456',
          },
        );

        final json = episode.toJson();
        final restored = Episode.fromJson(json);

        expect(restored, equals(episode));
        expect(restored.platformLinks, isNotNull);
        expect(restored.platformLinks!.length, equals(2));
        expect(
          restored.platformLinks!['bilibili'],
          equals('https://bilibili.com/ep/123'),
        );
      },
    );

    // Test Episode with null optional fields
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any Episode with null fields, round-trip preserves nulls',
      (id) {
        final episode = Episode(
          id: id,
          seasonId: 'season-123',
          episodeNumber: 1,
        );

        final json = episode.toJson();
        final restored = Episode.fromJson(json);

        expect(restored, equals(episode));
        expect(restored.title, isNull);
        expect(restored.synopsis, isNull);
        expect(restored.duration, isNull);
        expect(restored.platformLinks, isNull);
      },
    );

    // Test SourceMaterial round-trip
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any SourceMaterial, toJson then fromJson produces equivalent object',
      (id, title) {
        final source = SourceMaterial(
          id: id,
          animeId: 'anime-123',
          type: SourceMaterialType.novel,
          title: title,
          author: 'Test Author',
          platform: '起点读书',
          platformUrl: 'https://qidian.com/book/123',
          coverUrl: 'https://example.com/cover.jpg',
          synopsis: 'Novel synopsis',
          totalChapters: 500,
          latestChapter: 450,
          latestChapterTitle: 'Chapter 450',
          lastUpdated: DateTime(2024, 6, 1),
          updateStatus: SourceUpdateStatus.ongoing,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 6, 1),
        );

        final json = source.toJson();
        final restored = SourceMaterial.fromJson(json);

        expect(restored, equals(source));
      },
    );

    // Test SourceMaterial with nested chapters
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any SourceMaterial with chapters, round-trip preserves nested data',
      (id) {
        final chapters = [
          Chapter(
            id: 'ch-1',
            sourceMaterialId: id,
            chapterNumber: 1,
            title: 'Chapter 1',
            wordCount: 3000,
            publishDate: DateTime(2024, 1, 1),
            isPaid: false,
          ),
          Chapter(
            id: 'ch-2',
            sourceMaterialId: id,
            chapterNumber: 2,
            title: 'Chapter 2',
            wordCount: 3500,
            publishDate: DateTime(2024, 1, 2),
            isPaid: true,
          ),
        ];

        final source = SourceMaterial(
          id: id,
          animeId: 'anime-123',
          type: SourceMaterialType.novel,
          chapters: chapters,
        );

        final json = source.toJson();
        final restored = SourceMaterial.fromJson(json);

        expect(restored, equals(source));
        expect(restored.chapters, isNotNull);
        expect(restored.chapters!.length, equals(2));
      },
    );

    // Test all SourceMaterialType values round-trip
    test(
      'All SourceMaterialType values serialize and deserialize correctly',
      () {
        for (final type in SourceMaterialType.values) {
          final source = SourceMaterial(
            id: 'test-id',
            animeId: 'anime-123',
            type: type,
          );

          final json = source.toJson();
          final restored = SourceMaterial.fromJson(json);

          expect(restored.type, equals(type));
        }
      },
    );

    // Test all SourceUpdateStatus values round-trip
    test(
      'All SourceUpdateStatus values serialize and deserialize correctly',
      () {
        for (final status in SourceUpdateStatus.values) {
          final source = SourceMaterial(
            id: 'test-id',
            animeId: 'anime-123',
            type: SourceMaterialType.novel,
            updateStatus: status,
          );

          final json = source.toJson();
          final restored = SourceMaterial.fromJson(json);

          expect(restored.updateStatus, equals(status));
        }
      },
    );

    // Test Chapter round-trip
    Glados2<String, int>(
      any.nonEmptyLetterOrDigits,
      any.intInRange(1, 1000),
    ).test('For any Chapter, toJson then fromJson produces equivalent object', (
      id,
      chapterNumber,
    ) {
      final chapter = Chapter(
        id: id,
        sourceMaterialId: 'source-123',
        chapterNumber: chapterNumber,
        title: 'Chapter $chapterNumber',
        wordCount: 3000,
        publishDate: DateTime(2024, 5, 15),
        isPaid: chapterNumber > 100,
        createdAt: DateTime(2024, 5, 15),
      );

      final json = chapter.toJson();
      final restored = Chapter.fromJson(json);

      expect(restored, equals(chapter));
    });

    // Test Chapter with null optional fields
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any Chapter with null fields, round-trip preserves nulls',
      (id) {
        final chapter = Chapter(
          id: id,
          sourceMaterialId: 'source-123',
          chapterNumber: 1,
        );

        final json = chapter.toJson();
        final restored = Chapter.fromJson(json);

        expect(restored, equals(chapter));
        expect(restored.title, isNull);
        expect(restored.wordCount, isNull);
        expect(restored.publishDate, isNull);
        expect(restored.isPaid, isFalse);
      },
    );

    // Test Chapter isPaid boolean round-trip
    Glados<bool>(any.bool).test(
      'For any Chapter isPaid value, round-trip preserves boolean',
      (isPaid) {
        final chapter = Chapter(
          id: 'ch-1',
          sourceMaterialId: 'source-123',
          chapterNumber: 1,
          isPaid: isPaid,
        );

        final json = chapter.toJson();
        final restored = Chapter.fromJson(json);

        expect(restored.isPaid, equals(isPaid));
      },
    );
  });
}
