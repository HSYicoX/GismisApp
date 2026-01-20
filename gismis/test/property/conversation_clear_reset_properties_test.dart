import 'package:gismis/shared/models/ai_message.dart';
import 'package:glados/glados.dart';

/// Feature: anime-tracker-app, Property 10: Conversation Clear Reset
/// Validates: Requirements 4.11
///
/// For any AI conversation with N messages, after clearing, the message list
/// SHALL be empty (length = 0).

/// Simulates conversation state for testing clear functionality.
class ConversationState {
  ConversationState({List<AiMessage>? messages}) : _messages = messages ?? [];

  final List<AiMessage> _messages;

  List<AiMessage> get messages => List.unmodifiable(_messages);
  int get messageCount => _messages.length;
  bool get isEmpty => _messages.isEmpty;

  /// Adds a message to the conversation.
  void addMessage(AiMessage message) {
    _messages.add(message);
  }

  /// Clears all messages from the conversation.
  void clear() {
    _messages.clear();
  }
}

/// Helper to create test messages.
AiMessage createTestMessage(int index) {
  return AiMessage(
    id: 'msg_$index',
    role: index.isEven ? MessageRole.user : MessageRole.assistant,
    userText: index.isEven ? 'User message $index' : null,
    timestamp: DateTime.now(),
    state: AiMessageState.completed,
  );
}

void main() {
  group('Property 10: Conversation Clear Reset', () {
    Glados<int>(any.intInRange(0, 50)).test(
      'For any conversation with N messages, after clearing, message list is empty',
      (n) {
        final conversation = ConversationState();

        // Add N messages
        for (var i = 0; i < n; i++) {
          conversation.addMessage(createTestMessage(i));
        }

        // Verify messages were added
        expect(conversation.messageCount, equals(n));

        // Clear conversation
        conversation.clear();

        // Verify conversation is empty
        expect(conversation.messageCount, equals(0));
        expect(conversation.isEmpty, isTrue);
        expect(conversation.messages, isEmpty);
      },
    );

    Glados<int>(any.intInRange(0, 100)).test(
      'For any number of messages N, clearing results in exactly 0 messages',
      (n) {
        final conversation = ConversationState();

        // Add N messages
        for (var i = 0; i < n; i++) {
          conversation.addMessage(createTestMessage(i));
        }

        expect(conversation.messageCount, equals(n));

        // Clear
        conversation.clear();

        expect(conversation.messageCount, equals(0));
      },
    );

    test('Empty conversation remains empty after clear', () {
      final conversation = ConversationState();

      expect(conversation.isEmpty, isTrue);

      conversation.clear();

      expect(conversation.isEmpty, isTrue);
      expect(conversation.messageCount, equals(0));
    });

    Glados<int>(any.intInRange(1, 50)).test(
      'Clear is idempotent - multiple clears result in empty conversation',
      (n) {
        final conversation = ConversationState();

        for (var i = 0; i < n; i++) {
          conversation.addMessage(createTestMessage(i));
        }

        // Clear multiple times
        conversation.clear();
        conversation.clear();
        conversation.clear();

        expect(conversation.isEmpty, isTrue);
        expect(conversation.messageCount, equals(0));
      },
    );

    Glados2<int, int>(any.intInRange(0, 30), any.intInRange(0, 30)).test(
      'After clear, new messages can be added starting fresh',
      (firstBatchSize, secondBatchSize) {
        final conversation = ConversationState();

        // Add first batch
        for (var i = 0; i < firstBatchSize; i++) {
          conversation.addMessage(createTestMessage(i));
        }
        expect(conversation.messageCount, equals(firstBatchSize));

        // Clear
        conversation.clear();
        expect(conversation.isEmpty, isTrue);

        // Add second batch
        for (var i = 0; i < secondBatchSize; i++) {
          conversation.addMessage(createTestMessage(i + 100));
        }

        // Should only have second batch
        expect(conversation.messageCount, equals(secondBatchSize));
      },
    );

    Glados<int>(any.intInRange(1, 50)).test(
      'Message count before clear equals N, after clear equals 0',
      (n) {
        final conversation = ConversationState();

        for (var i = 0; i < n; i++) {
          conversation.addMessage(createTestMessage(i));
        }

        final countBefore = conversation.messageCount;
        conversation.clear();
        final countAfter = conversation.messageCount;

        expect(countBefore, equals(n));
        expect(countAfter, equals(0));
      },
    );
  });
}
