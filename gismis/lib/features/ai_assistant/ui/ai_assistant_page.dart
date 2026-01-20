import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../shared/models/ai_message.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../domain/ai_messages_notifier.dart';
import '../domain/ai_providers.dart';
import 'widgets/streaming_message_bubble.dart';

/// AI Assistant page for anime summaries, news, and Q&A.
///
/// Displays hot questions as chips, message list with streaming bubbles,
/// input field with mode selector, and handles error states with retry.
/// Shows offline banner when network is unavailable.
/// Requirements: 4.1, 4.2, 4.3, 4.7, 4.8, 4.10, 9.5
class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({this.animeId, super.key});

  /// Optional anime ID for context-specific questions.
  final String? animeId;

  @override
  ConsumerState<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends ConsumerState<AiAssistantPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Set anime context if provided
    if (widget.animeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(aiAnimeContextProvider.notifier).state = widget.animeId;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final mode = ref.read(aiModeProvider);
    final animeId = ref.read(aiAnimeContextProvider);

    _textController.clear();
    _focusNode.unfocus();

    await ref
        .read(aiMessagesProvider.notifier)
        .sendMessage(content.trim(), mode, animeId: animeId);

    _scrollToBottom();
  }

  Future<void> _retryLastMessage() async {
    final mode = ref.read(aiModeProvider);
    final animeId = ref.read(aiAnimeContextProvider);
    await ref
        .read(aiMessagesProvider.notifier)
        .retryLastMessage(mode, animeId: animeId);
  }

  void _clearConversation() {
    ref.read(aiMessagesProvider.notifier).clearConversation();
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(aiMessagesProvider);
    final isStreaming = messagesState.isStreaming;
    final isOffline = ref.watch(isOfflineProvider);

    // Scroll to bottom when new messages arrive
    ref.listen<AiMessagesState>(aiMessagesProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(messagesState),
      body: Column(
        children: [
          // Offline banner
          if (isOffline) const OfflineBanner(),
          Expanded(
            child: messagesState.messages.isEmpty
                ? _buildEmptyState()
                : _buildMessageList(messagesState),
          ),
          _buildInputArea(isStreaming),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AiMessagesState state) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      title: const Text('AI Assistant'),
      actions: [
        if (state.messages.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearConversation,
            tooltip: 'Clear conversation',
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(),
          AppSpacing.verticalLg,
          _buildModeSelector(),
          AppSpacing.verticalLg,
          _buildHotQuestions(),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ask me anything about anime',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.verticalSm,
        Text(
          widget.animeId != null
              ? 'I can help you with questions about this anime.'
              : 'Get summaries, news, source info, or ask questions.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    final currentMode = ref.watch(aiModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mode',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
        ),
        AppSpacing.verticalSm,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: AiMode.values.map((mode) {
            final isSelected = mode == currentMode;
            return ChoiceChip(
              label: Text(_getModeLabel(mode)),
              selected: isSelected,
              onSelected: (_) {
                ref.read(aiModeProvider.notifier).state = mode;
              },
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.accentSky.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected
                    ? AppColors.accentSky
                    : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.accentSky : AppColors.divider,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _getModeLabel(AiMode mode) {
    return switch (mode) {
      AiMode.summary => 'Summary',
      AiMode.news => 'News',
      AiMode.source => 'Source',
      AiMode.qa => 'Q&A',
    };
  }

  Widget _buildHotQuestions() {
    final hotQuestionsAsync = ref.watch(hotQuestionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trending Questions',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
        ),
        AppSpacing.verticalSm,
        hotQuestionsAsync.when(
          data: (questions) => Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: questions.map((q) {
              return ActionChip(
                label: Text(
                  q.question,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => _sendMessage(q.question),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.divider),
                labelStyle: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
              );
            }).toList(),
          ),
          loading: () => Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: List.generate(
              4,
              (_) => SkeletonLoader(
                width: 120,
                height: 32,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          error: (_, __) => Text(
            'Failed to load suggestions',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageList(AiMessagesState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        return GestureDetector(
          onTap: message.state == AiMessageState.error
              ? _retryLastMessage
              : null,
          child: StreamingMessageBubble(message: message),
        );
      },
    );
  }

  Widget _buildInputArea(bool isStreaming) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.pageHorizontal,
        right: AppSpacing.pageHorizontal,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              enabled: !isStreaming,
              decoration: InputDecoration(
                hintText: isStreaming
                    ? 'Waiting for response...'
                    : 'Ask a question...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.accentSky),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: isStreaming ? null : _sendMessage,
              maxLines: 3,
              minLines: 1,
            ),
          ),
          AppSpacing.horizontalSm,
          IconButton(
            onPressed: isStreaming
                ? null
                : () => _sendMessage(_textController.text),
            icon: Icon(
              Icons.send_rounded,
              color: isStreaming ? AppColors.textTertiary : AppColors.accentSky,
            ),
          ),
        ],
      ),
    );
  }
}
