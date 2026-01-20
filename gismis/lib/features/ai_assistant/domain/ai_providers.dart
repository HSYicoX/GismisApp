import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../shared/models/ai_message.dart';
import '../../../shared/models/hot_question.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/models/chat_message.dart';
import '../data/supabase_ai_repository.dart';
import 'ai_messages_notifier.dart';

/// Provider for the AiRepository instance (using Supabase).
final aiRepositoryProvider = Provider<SupabaseAiRepository>((ref) {
  final config = ref.watch(supabaseConfigProvider);
  final tokenStorage = ref.watch(secureStorageProvider);
  return SupabaseAiRepository(config: config, tokenStorage: tokenStorage);
});

/// Provider for hot questions based on trending topics.
/// Requirements: 4.1
final hotQuestionsProvider = FutureProvider<List<HotQuestion>>((ref) async {
  final repository = ref.watch(aiRepositoryProvider);
  return repository.getHotQuestions();
});

/// Provider for the current AI mode selection.
/// Requirements: 4.7
final aiModeProvider = StateProvider<AiMode>((ref) => AiMode.qa);

/// Provider for tracking if AI is currently streaming.
final aiStreamingProvider = StateProvider<bool>((ref) => false);

/// Provider for the current anime context (when accessed from anime detail).
final aiAnimeContextProvider = StateProvider<String?>((ref) => null);

/// Provider for the AI messages notifier.
/// Manages the conversation state and processes SSE events.
final aiMessagesProvider =
    StateNotifierProvider<AiMessagesNotifier, AiMessagesState>((ref) {
      final repository = ref.watch(aiRepositoryProvider);
      return AiMessagesNotifier(repository);
    });

/// Provider for the current conversation messages.
final aiConversationMessagesProvider = Provider<List<AiMessage>>((ref) {
  final state = ref.watch(aiMessagesProvider);
  return state.messages;
});

/// Provider for checking if conversation is empty.
final isConversationEmptyProvider = Provider<bool>((ref) {
  final state = ref.watch(aiMessagesProvider);
  return state.messages.isEmpty;
});

/// Provider for the current streaming state.
final isAiStreamingProvider = Provider<bool>((ref) {
  final state = ref.watch(aiMessagesProvider);
  return state.isStreaming;
});

/// Provider for the current error state.
final aiErrorProvider = Provider<String?>((ref) {
  final state = ref.watch(aiMessagesProvider);
  return state.error;
});

/// Provider family for AI assistant with anime context.
/// Used when accessing AI from anime detail page.
final aiAssistantWithContextProvider =
    Provider.family<AiMessagesNotifier, String?>((ref, animeId) {
      final notifier = ref.watch(aiMessagesProvider.notifier);

      // Set the anime context if provided
      if (animeId != null) {
        ref.read(aiAnimeContextProvider.notifier).state = animeId;
      }

      return notifier;
    });

/// Helper class for building AI chat requests with mode context.
class AiChatRequest {
  const AiChatRequest({
    required this.content,
    required this.mode,
    this.animeId,
  });

  final String content;
  final AiMode mode;
  final String? animeId;

  /// Converts to request body for API.
  Map<String, dynamic> toRequestBody(List<ChatMessage> messages) {
    final body = <String, dynamic>{
      'messages': messages.map((m) => m.toJson()).toList(),
      'mode': mode.value,
    };

    if (animeId != null) {
      body['anime_id'] = animeId;
    }

    return body;
  }
}
