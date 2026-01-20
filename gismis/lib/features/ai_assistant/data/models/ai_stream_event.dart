/// AI Stream Event types for Supabase Edge Function SSE responses.
///
/// These events are mapped from the underlying SSE events to provide
/// a cleaner API for AI-specific streaming responses.
///
/// Event types:
/// - [AIMetaEvent]: Initial metadata with conversation ID and model info
/// - [AIDeltaEvent]: Incremental text content
/// - [AIFieldStartEvent]: Indicates a field is starting to stream
/// - [AIFieldEndEvent]: Indicates a field has completed streaming
/// - [AIDoneEvent]: All streaming has completed
/// - [AIErrorEvent]: An error occurred during streaming
/// - [AIUnknownEvent]: Unknown event type (fallback)
///
/// Requirements: 7.2
library;

import 'package:meta/meta.dart';

/// Sealed class representing AI streaming events.
///
/// Maps from SSE events to AI-specific event types for cleaner handling
/// in the UI layer.
@immutable
sealed class AIStreamEvent {
  const AIStreamEvent();
}

/// Meta event containing conversation metadata.
///
/// Sent at the start of a streaming response with:
/// - [conversationId]: Unique identifier for the conversation
/// - [model]: The AI model being used (e.g., 'deepseek-chat', 'deepseek-reasoner')
@immutable
class AIMetaEvent extends AIStreamEvent {
  const AIMetaEvent({this.conversationId, this.model});

  /// Unique identifier for this conversation.
  final String? conversationId;

  /// The AI model being used for this response.
  final String? model;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIMetaEvent &&
          runtimeType == other.runtimeType &&
          conversationId == other.conversationId &&
          model == other.model;

  @override
  int get hashCode => Object.hash(conversationId, model);

  @override
  String toString() =>
      'AIMetaEvent(conversationId: $conversationId, model: $model)';
}

/// Delta event containing incremental text content.
///
/// Sent multiple times during streaming with chunks of the response text.
@immutable
class AIDeltaEvent extends AIStreamEvent {
  const AIDeltaEvent({required this.content});

  /// Incremental text content to append to the response.
  final String content;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIDeltaEvent &&
          runtimeType == other.runtimeType &&
          content == other.content;

  @override
  int get hashCode => content.hashCode;

  @override
  String toString() => 'AIDeltaEvent(content: $content)';
}

/// Event indicating a field is starting to stream.
///
/// Used for structured responses where multiple fields are streamed
/// (e.g., 'thinking', 'answer', 'sources').
@immutable
class AIFieldStartEvent extends AIStreamEvent {
  const AIFieldStartEvent({required this.field});

  /// Name of the field that is starting to stream.
  final String field;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIFieldStartEvent &&
          runtimeType == other.runtimeType &&
          field == other.field;

  @override
  int get hashCode => field.hashCode;

  @override
  String toString() => 'AIFieldStartEvent(field: $field)';
}

/// Event indicating a field has completed streaming.
@immutable
class AIFieldEndEvent extends AIStreamEvent {
  const AIFieldEndEvent({required this.field});

  /// Name of the field that has completed streaming.
  final String field;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIFieldEndEvent &&
          runtimeType == other.runtimeType &&
          field == other.field;

  @override
  int get hashCode => field.hashCode;

  @override
  String toString() => 'AIFieldEndEvent(field: $field)';
}

/// Event indicating all streaming has completed.
///
/// May include usage statistics like tokens used.
@immutable
class AIDoneEvent extends AIStreamEvent {
  const AIDoneEvent({this.tokensUsed});

  /// Number of tokens used in this response (if available).
  final int? tokensUsed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIDoneEvent &&
          runtimeType == other.runtimeType &&
          tokensUsed == other.tokensUsed;

  @override
  int get hashCode => tokensUsed.hashCode;

  @override
  String toString() => 'AIDoneEvent(tokensUsed: $tokensUsed)';
}

/// Error event indicating a streaming error occurred.
@immutable
class AIErrorEvent extends AIStreamEvent {
  const AIErrorEvent({required this.message});

  /// Error message describing what went wrong.
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIErrorEvent &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'AIErrorEvent(message: $message)';
}

/// Unknown event type (fallback for unrecognized events).
@immutable
class AIUnknownEvent extends AIStreamEvent {
  const AIUnknownEvent();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIUnknownEvent && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AIUnknownEvent()';
}
