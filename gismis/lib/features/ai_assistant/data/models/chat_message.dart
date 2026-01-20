/// Chat message model for AI conversations.
///
/// Represents a single message in an AI conversation, used for both
/// sending context to the AI and storing conversation history.
///
/// Requirements: 7.4
library;

import 'package:meta/meta.dart';

/// Role of a message in the conversation.
enum ChatMessageRole {
  /// Message from the user.
  user('user'),

  /// Message from the AI assistant.
  assistant('assistant'),

  /// System message (instructions/context).
  system('system');

  const ChatMessageRole(this.value);

  /// The string value used in API requests.
  final String value;

  /// Creates a [ChatMessageRole] from a string value.
  static ChatMessageRole fromString(String value) {
    return ChatMessageRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ChatMessageRole.user,
    );
  }
}

/// A single message in an AI conversation.
///
/// Used for:
/// - Sending conversation context to the AI
/// - Storing conversation history
/// - Displaying messages in the UI
@immutable
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.timestamp,
  });

  /// Creates a [ChatMessage] from JSON.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: ChatMessageRole.fromString(json['role'] as String),
      content: json['content'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }

  /// The role of the message sender.
  final ChatMessageRole role;

  /// The content of the message.
  final String content;

  /// When the message was created (optional).
  final DateTime? timestamp;

  /// Converts this message to JSON for API requests.
  Map<String, dynamic> toJson() {
    return {
      'role': role.value,
      'content': content,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
    };
  }

  /// Creates a user message.
  factory ChatMessage.user(String content, {DateTime? timestamp}) {
    return ChatMessage(
      role: ChatMessageRole.user,
      content: content,
      timestamp: timestamp,
    );
  }

  /// Creates an assistant message.
  factory ChatMessage.assistant(String content, {DateTime? timestamp}) {
    return ChatMessage(
      role: ChatMessageRole.assistant,
      content: content,
      timestamp: timestamp,
    );
  }

  /// Creates a system message.
  factory ChatMessage.system(String content) {
    return ChatMessage(role: ChatMessageRole.system, content: content);
  }

  /// Creates a copy with the given fields replaced.
  ChatMessage copyWith({
    ChatMessageRole? role,
    String? content,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          content == other.content &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(role, content, timestamp);

  @override
  String toString() =>
      'ChatMessage(role: ${role.value}, content: $content, timestamp: $timestamp)';
}
