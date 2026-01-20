/// Supabase AI Repository for streaming AI chat via Edge Functions.
///
/// This repository connects to Supabase Edge Functions for AI chat,
/// supporting both deepseek-chat and deepseek-reasoner models.
///
/// Access mode: Edge Function + SSE streaming response
///
/// DeepSeek models:
/// - deepseek-chat: DeepSeek-V3.2 (default, non-thinking mode)
/// - deepseek-reasoner: DeepSeek-V3.2 (thinking mode, user selectable)
///
/// Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6
library;

import 'package:dio/dio.dart';

import '../../../core/network/sse_client.dart';
import '../../../core/network/sse_event.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../shared/models/hot_question.dart';
import 'models/ai_stream_event.dart';
import 'models/chat_message.dart';

/// Repository for AI-related operations via Supabase Edge Functions.
///
/// Handles:
/// - Streaming AI chat responses via SSE
/// - Hot questions retrieval
/// - Model switching (deepseek-chat / deepseek-reasoner)
class SupabaseAiRepository {
  SupabaseAiRepository({
    required SupabaseConfig config,
    required SecureStorageService tokenStorage,
    SSEClient? sseClient,
    Dio? dio,
  }) : _config = config,
       _tokenStorage = tokenStorage,
       _sseClient = sseClient ?? SSEClient(),
       _dio = dio ?? Dio();

  final SupabaseConfig _config;
  final SecureStorageService _tokenStorage;
  final SSEClient _sseClient;
  final Dio _dio;

  /// Sends a message and streams the AI response.
  ///
  /// [message] - The user's message to send
  /// [conversationId] - Optional conversation ID for context continuity
  /// [context] - Optional list of previous messages for context
  /// [useReasoner] - Whether to use the reasoning model (deepseek-reasoner)
  ///
  /// Returns a stream of [AIStreamEvent] for progressive content updates.
  ///
  /// Requirements: 7.1, 7.2, 7.3, 7.4
  Stream<AIStreamEvent> chat({
    required String message,
    String? conversationId,
    List<ChatMessage>? context,
    bool useReasoner = false,
  }) async* {
    final token = await _tokenStorage.getAccessToken();
    if (token == null) {
      yield const AIErrorEvent(message: 'Not authenticated');
      return;
    }

    final body = <String, dynamic>{
      'message': message,
      'model': useReasoner ? 'deepseek-reasoner' : 'deepseek-chat',
      if (conversationId != null) 'conversationId': conversationId,
      if (context != null) 'context': context.map((m) => m.toJson()).toList(),
    };

    final stream = _sseClient.connect(
      '${_config.functionsUrl}/ai-chat',
      headers: {
        'Authorization': 'Bearer $token',
        'apikey': _config.anonKey,
        'Content-Type': 'application/json',
      },
      body: body,
    );

    await for (final event in stream) {
      yield mapSSEEvent(event);
    }
  }

  /// Fetches hot questions from the AI service.
  ///
  /// Returns a list of suggested questions based on trending topics
  /// and optionally the user's history.
  ///
  /// Requirements: 7.1
  Future<List<HotQuestion>> getHotQuestions() async {
    final token = await _tokenStorage.getAccessToken();

    final response = await _dio.post<Map<String, dynamic>>(
      '${_config.functionsUrl}/ai-hot-questions',
      options: Options(
        headers: {
          'apikey': _config.anonKey,
          if (token != null) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );

    final data = response.data;
    if (data == null) {
      return [];
    }

    // Handle both 'questions' (string list) and 'items' (HotQuestion list) formats
    if (data.containsKey('questions')) {
      final questions = data['questions'] as List<dynamic>? ?? [];
      return questions
          .asMap()
          .entries
          .map(
            (entry) => HotQuestion(
              topic: 'hot_topic',
              question: entry.value as String,
              rank: entry.key,
            ),
          )
          .toList();
    }

    if (data.containsKey('items')) {
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((json) => HotQuestion.fromJson(json as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.rank.compareTo(b.rank));
    }

    return [];
  }

  /// Maps an SSE event to an AI stream event.
  ///
  /// This method is exposed for testing purposes.
  ///
  /// Requirements: 7.2
  AIStreamEvent mapSSEEvent(SSEEvent event) {
    return switch (event) {
      SSEMetaEvent e => AIMetaEvent(
        conversationId: e.messageId.isNotEmpty ? e.messageId : null,
        model: e.fields.isNotEmpty ? e.fields.first : null,
      ),
      SSEDeltaEvent e => AIDeltaEvent(content: e.text),
      SSEFieldStartEvent e => AIFieldStartEvent(field: e.field),
      SSEFieldEndEvent e => AIFieldEndEvent(field: e.field),
      SSEDoneEvent() => const AIDoneEvent(),
      SSEErrorEvent e => AIErrorEvent(message: e.message),
    };
  }

  /// Closes the current SSE connection.
  ///
  /// Requirements: 7.6
  void closeStream() {
    _sseClient.close();
  }

  /// Disposes of the repository and releases resources.
  void dispose() {
    _sseClient.dispose();
  }
}
