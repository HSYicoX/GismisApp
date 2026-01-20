import 'package:glados/glados.dart';

import 'package:gismis/shared/models/models.dart';

/// Feature: anime-tracker-app, Property 19: JSON Model Serialization Round-Trip
/// Validates: Requirements 10.3
///
/// For any Anime, AnimeDetail, UserAnimeFollow, or AiMessage object,
/// serializing to JSON and deserializing back SHALL produce an equivalent object.

void main() {
  group('Property 19: JSON Model Serialization Round-Trip', () {
    // Test Anime round-trip
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test('For any Anime, toJson then fromJson produces equivalent object', (
      id,
      title,
    ) {
      final anime = Anime(
        id: id,
        title: title,
        titleAlias: ['alias1', 'alias2'],
        coverUrl: 'https://example.com/cover.jpg',
        summary: 'Test summary',
        status: AnimeStatus.ongoing,
        updatedAt: DateTime(2024, 1, 15, 10, 30),
      );

      final json = anime.toJson();
      final restored = Anime.fromJson(json);

      expect(restored, equals(anime));
    });

    // Test Anime with null summary
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any Anime with null summary, round-trip preserves null',
      (id) {
        final anime = Anime(
          id: id,
          title: 'Test Title',
          titleAlias: [],
          coverUrl: 'https://example.com/cover.jpg',
          status: AnimeStatus.completed,
          updatedAt: DateTime(2024, 6),
        );

        final json = anime.toJson();
        final restored = Anime.fromJson(json);

        expect(restored, equals(anime));
        expect(restored.summary, isNull);
      },
    );

    // Test AnimePlatform round-trip
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any AnimePlatform, toJson then fromJson produces equivalent object',
      (platform, url) {
        final animePlatform = AnimePlatform(
          platform: platform,
          url: url,
          region: 'CN',
        );

        final json = animePlatform.toJson();
        final restored = AnimePlatform.fromJson(json);

        expect(restored, equals(animePlatform));
      },
    );

    // Test AnimeSchedule round-trip
    Glados<int>(any.intInRange(1, 8)).test(
      'For any AnimeSchedule with weekday 1-7, round-trip preserves values',
      (weekday) {
        final schedule = AnimeSchedule(weekday: weekday, updateTime: '20:00');

        final json = schedule.toJson();
        final restored = AnimeSchedule.fromJson(json);

        expect(restored, equals(schedule));
      },
    );

    // Test AnimeEpisodeState round-trip
    Glados<int>(any.positiveIntOrZero).test(
      'For any AnimeEpisodeState, toJson then fromJson produces equivalent object',
      (latestEpisode) {
        final episodeState = AnimeEpisodeState(
          latestEpisode: latestEpisode,
          latestTitle: 'Episode Title',
          latestBrief: 'Brief description',
          lastCheckedAt: DateTime(2024, 3, 20, 15, 45),
        );

        final json = episodeState.toJson();
        final restored = AnimeEpisodeState.fromJson(json);

        expect(restored, equals(episodeState));
      },
    );

    // Test User round-trip
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test('For any User, toJson then fromJson produces equivalent object', (
      id,
      username,
    ) {
      final user = User(
        id: id,
        email: 'test@example.com',
        username: username,
        avatarUrl: 'https://example.com/avatar.jpg',
      );

      final json = user.toJson();
      final restored = User.fromJson(json);

      expect(restored, equals(user));
    });

    // Test UserAnimeFollow round-trip
    Glados2<String, int>(
      any.nonEmptyLetterOrDigits,
      any.positiveIntOrZero,
    ).test(
      'For any UserAnimeFollow, toJson then fromJson produces equivalent object',
      (animeId, progressEpisode) {
        final follow = UserAnimeFollow(
          id: 'follow-123',
          animeId: animeId,
          progressEpisode: progressEpisode,
          followWeekdayOverride: 3,
          notes: 'My notes',
          isFavorite: true,
        );

        final json = follow.toJson();
        final restored = UserAnimeFollow.fromJson(json);

        expect(restored, equals(follow));
      },
    );

    // Test FieldContent round-trip
    Glados<String>(any.letterOrDigits).test(
      'For any FieldContent, toJson then fromJson produces equivalent object',
      (text) {
        final fieldContent = FieldContent(
          text: text,
          state: FieldState.blurred,
        );

        final json = fieldContent.toJson();
        final restored = FieldContent.fromJson(json);

        expect(restored, equals(fieldContent));
      },
    );

    // Test AiResponseContent round-trip
    test(
      'For AiResponseContent with multiple fields, round-trip preserves all fields',
      () {
        final content = AiResponseContent(
          fields: {
            'summary': const FieldContent(
              text: 'Summary text',
              state: FieldState.completed,
            ),
            'key_points': const FieldContent(
              text: 'Key points text',
              state: FieldState.clear,
            ),
          },
        );

        final json = content.toJson();
        final restored = AiResponseContent.fromJson(json);

        expect(restored, equals(content));
      },
    );

    // Test AiMessage round-trip
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any AiMessage, toJson then fromJson produces equivalent object',
      (id) {
        final message = AiMessage(
          id: id,
          role: MessageRole.assistant,
          content: const AiResponseContent(
            fields: {
              'response': FieldContent(
                text: 'AI response',
                state: FieldState.completed,
              ),
            },
          ),
          timestamp: DateTime(2024, 5, 10, 12),
          state: AiMessageState.completed,
        );

        final json = message.toJson();
        final restored = AiMessage.fromJson(json);

        expect(restored, equals(message));
      },
    );

    // Test AiMessage user message round-trip
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any user AiMessage, toJson then fromJson produces equivalent object',
      (userText) {
        final message = AiMessage(
          id: 'msg-user-1',
          role: MessageRole.user,
          userText: userText,
          timestamp: DateTime(2024, 5, 10, 11, 59),
          state: AiMessageState.completed,
        );

        final json = message.toJson();
        final restored = AiMessage.fromJson(json);

        expect(restored, equals(message));
      },
    );

    // Test AuthTokens round-trip
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any AuthTokens, toJson then fromJson produces equivalent object',
      (accessToken, refreshToken) {
        final tokens = AuthTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiresAt: DateTime(2024, 12, 31, 23, 59),
        );

        final json = tokens.toJson();
        final restored = AuthTokens.fromJson(json);

        expect(restored, equals(tokens));
      },
    );

    // Test HotQuestion round-trip
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any HotQuestion, toJson then fromJson produces equivalent object',
      (topic, question) {
        final hotQuestion = HotQuestion(
          topic: topic,
          question: question,
          rank: 5,
        );

        final json = hotQuestion.toJson();
        final restored = HotQuestion.fromJson(json);

        expect(restored, equals(hotQuestion));
      },
    );

    // Test AnimeDetail round-trip
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any AnimeDetail, toJson then fromJson produces equivalent object',
      (id) {
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

        final json = detail.toJson();
        final restored = AnimeDetail.fromJson(json);

        expect(restored, equals(detail));
      },
    );

    // Test ScheduleEntry round-trip
    Glados<int>(any.positiveIntOrZero).test(
      'For any ScheduleEntry, toJson then fromJson produces equivalent object',
      (latestEpisode) {
        final entry = ScheduleEntry(
          anime: Anime(
            id: 'anime-1',
            title: 'Test Anime',
            titleAlias: [],
            coverUrl: 'https://example.com/cover.jpg',
            status: AnimeStatus.ongoing,
            updatedAt: DateTime(2024, 2, 15),
          ),
          userFollow: const UserAnimeFollow(
            id: 'follow-1',
            animeId: 'anime-1',
            progressEpisode: 5,
            isFavorite: false,
          ),
          latestEpisode: latestEpisode,
        );

        final json = entry.toJson();
        final restored = ScheduleEntry.fromJson(json);

        expect(restored, equals(entry));
      },
    );

    // Test all AnimeStatus values round-trip
    test('All AnimeStatus values serialize and deserialize correctly', () {
      for (final status in AnimeStatus.values) {
        final anime = Anime(
          id: 'test-id',
          title: 'Test',
          titleAlias: [],
          coverUrl: 'https://example.com/cover.jpg',
          status: status,
          updatedAt: DateTime(2024),
        );

        final json = anime.toJson();
        final restored = Anime.fromJson(json);

        expect(restored.status, equals(status));
      }
    });

    // Test all MessageRole values round-trip
    test('All MessageRole values serialize and deserialize correctly', () {
      for (final role in MessageRole.values) {
        final message = AiMessage(
          id: 'msg-1',
          role: role,
          userText: role == MessageRole.user ? 'User text' : null,
          timestamp: DateTime(2024),
          state: AiMessageState.completed,
        );

        final json = message.toJson();
        final restored = AiMessage.fromJson(json);

        expect(restored.role, equals(role));
      }
    });

    // Test all AiMessageState values round-trip
    test('All AiMessageState values serialize and deserialize correctly', () {
      for (final state in AiMessageState.values) {
        final message = AiMessage(
          id: 'msg-1',
          role: MessageRole.assistant,
          timestamp: DateTime(2024),
          state: state,
        );

        final json = message.toJson();
        final restored = AiMessage.fromJson(json);

        expect(restored.state, equals(state));
      }
    });

    // Test all FieldState values round-trip
    test('All FieldState values serialize and deserialize correctly', () {
      for (final state in FieldState.values) {
        final fieldContent = FieldContent(text: 'Test text', state: state);

        final json = fieldContent.toJson();
        final restored = FieldContent.fromJson(json);

        expect(restored.state, equals(state));
      }
    });
  });
}
