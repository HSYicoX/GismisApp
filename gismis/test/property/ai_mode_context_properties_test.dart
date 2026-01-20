import 'package:glados/glados.dart';

import 'package:gismis/features/ai_assistant/data/models/chat_message.dart';
import 'package:gismis/features/ai_assistant/domain/ai_providers.dart';
import 'package:gismis/shared/models/ai_message.dart';

/// Feature: anime-tracker-app, Property 9: AI Mode Context Inclusion
/// Validates: Requirements 4.7
///
/// For any AI chat request with a selected mode (summary/news/source/qa),
/// the request payload SHALL include the mode parameter matching the user's selection.

void main() {
  group('Property 9: AI Mode Context Inclusion', () {
    Glados<AiMode>(any.choose(AiMode.values)).test(
      'For any AI mode, request body includes the mode parameter',
      (mode) {
        final request = AiChatRequest(content: 'Test question', mode: mode);

        final messages = [
          ChatMessage(role: ChatMessageRole.user, content: 'Test question'),
        ];

        final body = request.toRequestBody(messages);

        expect(body.containsKey('mode'), isTrue);
        expect(body['mode'], equals(mode.value));
      },
    );

    Glados2<AiMode, String>(
      any.choose(AiMode.values),
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any mode and content, request body contains correct mode value',
      (mode, content) {
        final request = AiChatRequest(content: content, mode: mode);

        final messages = [
          ChatMessage(role: ChatMessageRole.user, content: content),
        ];

        final body = request.toRequestBody(messages);

        expect(body['mode'], equals(mode.value));
      },
    );

    Glados3<AiMode, String, String>(
      any.choose(AiMode.values),
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any mode with anime context, request includes both mode and anime_id',
      (mode, content, animeId) {
        final request = AiChatRequest(
          content: content,
          mode: mode,
          animeId: animeId,
        );

        final messages = [
          ChatMessage(role: ChatMessageRole.user, content: content),
        ];

        final body = request.toRequestBody(messages);

        expect(body['mode'], equals(mode.value));
        expect(body['anime_id'], equals(animeId));
      },
    );

    Glados<AiMode>(any.choose(AiMode.values)).test(
      'For any mode without anime context, request does not include anime_id',
      (mode) {
        final request = AiChatRequest(content: 'Test question', mode: mode);

        final messages = [
          ChatMessage(role: ChatMessageRole.user, content: 'Test question'),
        ];

        final body = request.toRequestBody(messages);

        expect(body.containsKey('anime_id'), isFalse);
      },
    );

    // Test all mode values are correctly serialized
    test('Summary mode serializes to "summary"', () {
      expect(AiMode.summary.value, equals('summary'));
    });

    test('News mode serializes to "news"', () {
      expect(AiMode.news.value, equals('news'));
    });

    test('Source mode serializes to "source"', () {
      expect(AiMode.source.value, equals('source'));
    });

    test('QA mode serializes to "qa"', () {
      expect(AiMode.qa.value, equals('qa'));
    });

    Glados2<AiMode, List<String>>(
      any.choose(AiMode.values),
      any.list(any.nonEmptyLetterOrDigits),
    ).test(
      'For any mode and message history, all messages are included in request',
      (mode, messageContents) {
        final request = AiChatRequest(
          content: messageContents.isNotEmpty ? messageContents.last : 'test',
          mode: mode,
        );

        final messages = messageContents
            .asMap()
            .entries
            .map(
              (e) => ChatMessage(
                role: e.key.isEven
                    ? ChatMessageRole.user
                    : ChatMessageRole.assistant,
                content: e.value,
              ),
            )
            .toList();

        final body = request.toRequestBody(messages);

        expect(body['messages'], isA<List<dynamic>>());
        final bodyMessages = body['messages'] as List<dynamic>;
        expect(bodyMessages.length, equals(messages.length));
      },
    );

    // Test ChatMessage serialization
    Glados2<ChatMessageRole, String>(
      any.choose(ChatMessageRole.values),
      any.nonEmptyLetterOrDigits,
    ).test('ChatMessage toJson includes role and content', (role, content) {
      final message = ChatMessage(role: role, content: content);

      final json = message.toJson();

      expect(json['role'], equals(role.value));
      expect(json['content'], equals(content));
    });
  });
}
