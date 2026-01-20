import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/models/ai_message.dart';
import '../../../../shared/widgets/field_blur_text.dart';
import '../../../../shared/widgets/skeleton_loader.dart';

/// A message bubble widget for AI streaming responses.
///
/// Renders multiple FieldBlurText widgets for each field in the response.
/// Shows skeleton for pending fields and progressively reveals content
/// as fields complete streaming.
/// Requirements: 4.4, 4.5, 4.6
class StreamingMessageBubble extends StatelessWidget {
  const StreamingMessageBubble({required this.message, super.key});

  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.role == MessageRole.assistant) ...[
            _buildAvatar(isUser: false),
            AppSpacing.horizontalSm,
          ],
          Expanded(child: _buildBubbleContent(context)),
          if (message.role == MessageRole.user) ...[
            AppSpacing.horizontalSm,
            _buildAvatar(isUser: true),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar({required bool isUser}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser ? AppColors.accentOlive : AppColors.accentSky,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Icon(
        isUser ? Icons.person_outline : Icons.auto_awesome,
        size: 18,
        color: AppColors.surface,
      ),
    );
  }

  Widget _buildBubbleContent(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final textStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary, height: 1.6);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isUser ? AppColors.surfaceVariant : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: isUser
          ? _buildUserContent(textStyle)
          : _buildAssistantContent(textStyle),
    );
  }

  Widget _buildUserContent(TextStyle? textStyle) {
    return Text(message.userText ?? '', style: textStyle);
  }

  Widget _buildAssistantContent(TextStyle? textStyle) {
    return switch (message.state) {
      AiMessageState.pending => _buildPendingState(),
      AiMessageState.streaming => _buildStreamingState(textStyle),
      AiMessageState.completed => _buildCompletedState(textStyle),
      AiMessageState.error => _buildErrorState(textStyle),
    };
  }

  Widget _buildPendingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TypingIndicator(),
        AppSpacing.verticalSm,
        SkeletonLoader.text(),
        AppSpacing.verticalXs,
        SkeletonLoader.text(width: 200),
      ],
    );
  }

  Widget _buildStreamingState(TextStyle? textStyle) {
    final content = message.content;
    if (content == null || content.fields.isEmpty) {
      return _buildPendingState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildFieldWidgets(content.fields, textStyle),
    );
  }

  Widget _buildCompletedState(TextStyle? textStyle) {
    final content = message.content;
    if (content == null || content.fields.isEmpty) {
      return Text('No content available', style: textStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildFieldWidgets(content.fields, textStyle),
    );
  }

  Widget _buildErrorState(TextStyle? textStyle) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
        AppSpacing.horizontalSm,
        Expanded(
          child: Text(
            'Failed to get response. Tap to retry.',
            style: textStyle?.copyWith(color: AppColors.error),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFieldWidgets(
    Map<String, FieldContent> fields,
    TextStyle? textStyle,
  ) {
    final widgets = <Widget>[];
    final entries = fields.entries.toList();

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final fieldName = entry.key;
      final fieldContent = entry.value;

      // Add field label for multi-field responses
      if (entries.length > 1) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              top: i > 0 ? AppSpacing.md : 0,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              _formatFieldName(fieldName),
              style: textStyle?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        );
      }

      // Add field content with blur animation
      widgets.add(
        FieldBlurText(
          text: fieldContent.text,
          state: fieldContent.state,
          style: textStyle,
        ),
      );
    }

    return widgets;
  }

  String _formatFieldName(String fieldName) {
    // Convert snake_case to Title Case
    return fieldName
        .split('_')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
  }
}

/// A simple user message bubble without streaming.
class UserMessageBubble extends StatelessWidget {
  const UserMessageBubble({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary, height: 1.6);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.divider, width: 0.5),
              ),
              child: Text(text, style: textStyle),
            ),
          ),
          AppSpacing.horizontalSm,
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accentOlive,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 18,
              color: AppColors.surface,
            ),
          ),
        ],
      ),
    );
  }
}
