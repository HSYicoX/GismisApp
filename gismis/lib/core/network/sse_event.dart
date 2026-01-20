import 'dart:convert';

/// Sealed class representing Server-Sent Events for AI streaming responses.
///
/// Event types follow the SSE protocol defined in the design document:
/// - meta: Initial metadata with message_id and field list
/// - field_start: Indicates a field is starting to stream
/// - delta: Incremental text content for a field
/// - field_end: Indicates a field has completed streaming
/// - done: All fields have completed
/// - error: An error occurred during streaming
sealed class SSEEvent {
  const SSEEvent();

  /// Parses a raw SSE event string into an SSEEvent object.
  ///
  /// Expected format:
  /// ```
  /// event: <event_type>
  /// data: <json_data>
  /// ```
  static SSEEvent? parse(String rawEvent) {
    if (rawEvent.trim().isEmpty) return null;

    String? eventType;
    String? dataContent;

    final lines = rawEvent.split('\n');
    for (final line in lines) {
      if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataContent = line.substring(5).trim();
      }
    }

    if (eventType == null || dataContent == null) {
      return null;
    }

    try {
      final data = jsonDecode(dataContent) as Map<String, dynamic>;
      return _parseEvent(eventType, data);
    } catch (e) {
      // If JSON parsing fails, try to handle as plain text for error messages
      if (eventType == 'error') {
        return SSEErrorEvent(message: dataContent);
      }
      return null;
    }
  }

  static SSEEvent? _parseEvent(String eventType, Map<String, dynamic> data) {
    switch (eventType) {
      case 'meta':
        return SSEMetaEvent(
          messageId: data['message_id'] as String? ?? '',
          fields:
              (data['fields'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [],
        );
      case 'field_start':
        return SSEFieldStartEvent(field: data['field'] as String? ?? '');
      case 'delta':
        return SSEDeltaEvent(
          field: data['field'] as String? ?? '',
          text: data['text'] as String? ?? '',
        );
      case 'field_end':
        return SSEFieldEndEvent(field: data['field'] as String? ?? '');
      case 'done':
        return const SSEDoneEvent();
      case 'error':
        return SSEErrorEvent(
          message: data['message'] as String? ?? 'Unknown error',
        );
      default:
        return null;
    }
  }
}

/// Meta event containing message ID and list of fields to expect.
class SSEMetaEvent extends SSEEvent {
  const SSEMetaEvent({required this.messageId, required this.fields});

  /// Unique identifier for this message.
  final String messageId;

  /// List of field names that will be streamed.
  final List<String> fields;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SSEMetaEvent &&
          runtimeType == other.runtimeType &&
          messageId == other.messageId &&
          _listEquals(fields, other.fields);

  @override
  int get hashCode => Object.hash(messageId, Object.hashAll(fields));

  @override
  String toString() => 'SSEMetaEvent(messageId: $messageId, fields: $fields)';
}

/// Event indicating a field is starting to stream.
class SSEFieldStartEvent extends SSEEvent {
  const SSEFieldStartEvent({required this.field});

  /// Name of the field that is starting.
  final String field;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SSEFieldStartEvent &&
          runtimeType == other.runtimeType &&
          field == other.field;

  @override
  int get hashCode => field.hashCode;

  @override
  String toString() => 'SSEFieldStartEvent(field: $field)';
}

/// Delta event containing incremental text content.
class SSEDeltaEvent extends SSEEvent {
  const SSEDeltaEvent({required this.field, required this.text});

  /// Name of the field this delta belongs to.
  final String field;

  /// Incremental text content.
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SSEDeltaEvent &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          text == other.text;

  @override
  int get hashCode => Object.hash(field, text);

  @override
  String toString() => 'SSEDeltaEvent(field: $field, text: $text)';
}

/// Event indicating a field has completed streaming.
class SSEFieldEndEvent extends SSEEvent {
  const SSEFieldEndEvent({required this.field});

  /// Name of the field that has completed.
  final String field;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SSEFieldEndEvent &&
          runtimeType == other.runtimeType &&
          field == other.field;

  @override
  int get hashCode => field.hashCode;

  @override
  String toString() => 'SSEFieldEndEvent(field: $field)';
}

/// Event indicating all streaming has completed.
class SSEDoneEvent extends SSEEvent {
  const SSEDoneEvent();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SSEDoneEvent && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'SSEDoneEvent()';
}

/// Error event indicating a streaming error occurred.
class SSEErrorEvent extends SSEEvent {
  const SSEErrorEvent({required this.message});

  /// Error message describing what went wrong.
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SSEErrorEvent &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'SSEErrorEvent(message: $message)';
}

/// Helper function to compare lists for equality.
bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
