import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/sse_client.dart';
import '../../../core/network/sse_event.dart';
import '../../../shared/models/ai_message.dart';
import '../../../shared/models/hot_question.dart';

/// Chat message for AI conversation.
class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final MessageRole role;
  final String content;

  Map<String, dynamic> toJson() {
    return {'role': role.value, 'content': content};
  }
}

/// Repository for AI-related data operations.
///
/// Handles fetching hot questions and streaming AI chat responses.
/// Implements reconnection logic for SSE connections.
class AiRepository {
  AiRepository({required DioClient dioClient, SSEClient? sseClient})
    : _dioClient = dioClient,
      _sseClient = sseClient ?? SSEClient();

  final DioClient _dioClient;
  final SSEClient _sseClient;

  /// Fetches suggested hot questions based on trending topics.
  ///
  /// Returns a list of [HotQuestion] sorted by rank.
  /// Requirements: 4.1
  Future<List<HotQuestion>> getHotQuestions() async {
    try {
      final response = await _dioClient.get<Map<String, dynamic>>(
        '/ai/suggestions',
      );

      final data = response.data!;
      final itemsJson = data['items'] as List<dynamic>? ?? [];

      final questions = itemsJson
          .map((json) => HotQuestion.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort by rank
      questions.sort((a, b) => a.rank.compareTo(b.rank));

      return questions;
    } on ApiException {
      rethrow;
    }
  }

  /// Streams AI chat responses using Server-Sent Events.
  ///
  /// [messages] - List of chat messages in the conversation
  /// [mode] - AI mode (summary, news, source, qa)
  /// [animeId] - Optional anime ID for context-specific questions
  ///
  /// Returns a stream of [SSEEvent] for progressive content updates.
  /// Requirements: 4.3, 4.9
  Stream<SSEEvent> streamChat(
    List<ChatMessage> messages,
    AiMode mode, {
    String? animeId,
  }) {
    final body = <String, dynamic>{
      'messages': messages.map((m) => m.toJson()).toList(),
      'mode': mode.value,
    };

    if (animeId != null) {
      body['anime_id'] = animeId;
    }

    return _sseClient.connect(
      '${_dioClient.dio.options.baseUrl}/ai/chat/stream',
      headers: _buildHeaders(),
      body: body,
    );
  }

  /// Builds headers for SSE connection including auth token.
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};

    // Get auth token from dio interceptors if available
    final authHeader = _dioClient.dio.options.headers['Authorization'];
    if (authHeader != null) {
      headers['Authorization'] = authHeader.toString();
    }

    return headers;
  }

  /// Closes the current SSE connection.
  void closeStream() {
    _sseClient.close();
  }

  /// Disposes of the repository and releases resources.
  void dispose() {
    _sseClient.dispose();
  }
}
