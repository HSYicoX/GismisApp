import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/ai_message.dart';
import '../data/models/ai_stream_event.dart';
import '../data/models/chat_message.dart';
import '../data/supabase_ai_repository.dart';

/// State class for AI messages list.
class AiMessagesState {
  const AiMessagesState({
    this.messages = const [],
    this.isStreaming = false,
    this.error,
  });

  final List<AiMessage> messages;
  final bool isStreaming;
  final String? error;

  AiMessagesState copyWith({
    List<AiMessage>? messages,
    bool? isStreaming,
    String? error,
  }) {
    return AiMessagesState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error,
    );
  }
}

/// StateNotifier for managing AI conversation messages.
///
/// Processes AI stream events and updates field states for streaming responses.
/// Requirements: 4.4, 4.5, 4.6, 4.11
class AiMessagesNotifier extends StateNotifier<AiMessagesState> {
  AiMessagesNotifier(this._repository) : super(const AiMessagesState());

  final SupabaseAiRepository _repository;
  StreamSubscription<AIStreamEvent>? _streamSubscription;
  final _uuid = const Uuid();
  String? _currentConversationId;

  /// Sends a message and streams the AI response.
  ///
  /// [content] - User's message content
  /// [mode] - AI mode for context
  /// [animeId] - Optional anime ID for context-specific questions
  Future<void> sendMessage(
    String content,
    AiMode mode, {
    String? animeId,
  }) async {
    if (state.isStreaming) return;

    // Add user message
    final userMessage = AiMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      userText: content,
      timestamp: DateTime.now(),
      state: AiMessageState.completed,
    );

    // Create placeholder assistant message
    final assistantMessage = AiMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      state: AiMessageState.pending,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage, assistantMessage],
      isStreaming: true,
    );

    // Build chat context for API
    final context = state.messages
        .where((m) => m.role == MessageRole.user && m.userText != null)
        .map(
          (m) => ChatMessage(
            role: m.role == MessageRole.user
                ? ChatMessageRole.user
                : ChatMessageRole.assistant,
            content: m.userText!,
          ),
        )
        .toList();

    try {
      // Use reasoner mode for 'qa' mode, otherwise use default chat model
      final useReasoner = mode == AiMode.qa;

      final stream = _repository.chat(
        message: content,
        conversationId: _currentConversationId,
        context: context.length > 1
            ? context.sublist(0, context.length - 1)
            : null,
        useReasoner: useReasoner,
      );
      await _processStream(stream, assistantMessage.id);
    } on Exception catch (e) {
      _handleError(assistantMessage.id, e.toString());
    }
  }

  /// Processes the AI stream and updates message state.
  Future<void> _processStream(
    Stream<AIStreamEvent> stream,
    String messageId,
  ) async {
    final fieldContents = <String, FieldContent>{};
    String? currentField;

    await for (final event in stream) {
      switch (event) {
        case AIMetaEvent(:final conversationId):
          _currentConversationId = conversationId;
          // Initialize with a default 'content' field
          fieldContents['content'] = const FieldContent(
            text: '',
            state: FieldState.skeleton,
          );
          _updateAssistantMessage(
            messageId,
            AiMessageState.streaming,
            fieldContents,
          );

        case AIFieldStartEvent(:final field):
          currentField = field;
          fieldContents[field] = const FieldContent(
            text: '',
            state: FieldState.blurred,
          );
          _updateAssistantMessage(
            messageId,
            AiMessageState.streaming,
            fieldContents,
          );

        case AIDeltaEvent(:final content):
          // Append text to current field or default 'content' field
          final targetField = currentField ?? 'content';
          if (fieldContents.containsKey(targetField)) {
            final current = fieldContents[targetField]!;
            fieldContents[targetField] = current.copyWith(
              text: current.text + content,
              state: FieldState.blurred,
            );
          } else {
            fieldContents[targetField] = FieldContent(
              text: content,
              state: FieldState.blurred,
            );
          }
          _updateAssistantMessage(
            messageId,
            AiMessageState.streaming,
            fieldContents,
          );

        case AIFieldEndEvent(:final field):
          if (fieldContents.containsKey(field)) {
            fieldContents[field] = fieldContents[field]!.copyWith(
              state: FieldState.clear,
            );
            _updateAssistantMessage(
              messageId,
              AiMessageState.streaming,
              fieldContents,
            );
          }
          currentField = null;

        case AIDoneEvent():
          // Mark all fields as completed
          for (final field in fieldContents.keys) {
            fieldContents[field] = fieldContents[field]!.copyWith(
              state: FieldState.completed,
            );
          }
          _updateAssistantMessage(
            messageId,
            AiMessageState.completed,
            fieldContents,
          );
          state = state.copyWith(isStreaming: false);

        case AIErrorEvent(:final message):
          _handleError(messageId, message);

        case AIUnknownEvent():
          // Ignore unknown events
          break;
      }
    }
  }

  /// Updates the assistant message with new content and state.
  void _updateAssistantMessage(
    String messageId,
    AiMessageState messageState,
    Map<String, FieldContent> fieldContents,
  ) {
    final messages = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(
          state: messageState,
          content: AiResponseContent(fields: Map.from(fieldContents)),
        );
      }
      return m;
    }).toList();

    state = state.copyWith(messages: messages);
  }

  /// Handles streaming errors.
  void _handleError(String messageId, String errorMessage) {
    final messages = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(state: AiMessageState.error);
      }
      return m;
    }).toList();

    state = state.copyWith(
      messages: messages,
      isStreaming: false,
      error: errorMessage,
    );
  }

  /// Clears all messages in the conversation.
  /// Requirements: 4.11
  void clearConversation() {
    _streamSubscription?.cancel();
    _repository.closeStream();
    _currentConversationId = null;
    state = const AiMessagesState();
  }

  /// Retries the last failed message.
  Future<void> retryLastMessage(AiMode mode, {String? animeId}) async {
    if (state.messages.isEmpty) return;

    // Find the last user message
    final lastUserMessageIndex = state.messages.lastIndexWhere(
      (m) => m.role == MessageRole.user,
    );

    if (lastUserMessageIndex == -1) return;

    final lastUserMessage = state.messages[lastUserMessageIndex];
    final content = lastUserMessage.userText;

    if (content == null) return;

    // Remove the failed assistant message
    final messages = state.messages.sublist(0, lastUserMessageIndex + 1);
    state = state.copyWith(messages: messages);

    // Resend
    await sendMessage(content, mode, animeId: animeId);
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _repository.closeStream();
    super.dispose();
  }
}
