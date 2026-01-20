/// AI message role enum.
enum MessageRole {
  user('user'),
  assistant('assistant');

  final String value;
  const MessageRole(this.value);

  static MessageRole fromString(String value) {
    return MessageRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MessageRole.user,
    );
  }
}

/// AI message state enum.
enum AiMessageState {
  pending('pending'),
  streaming('streaming'),
  completed('completed'),
  error('error');

  final String value;
  const AiMessageState(this.value);

  static AiMessageState fromString(String value) {
    return AiMessageState.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AiMessageState.pending,
    );
  }
}

/// Field state enum for streaming content.
enum FieldState {
  hidden('hidden'),
  skeleton('skeleton'),
  blurred('blurred'),
  clear('clear'),
  completed('completed');

  final String value;
  const FieldState(this.value);

  static FieldState fromString(String value) {
    return FieldState.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FieldState.hidden,
    );
  }
}

/// AI mode enum for different AI prompt contexts.
enum AiMode {
  summary('summary'),
  news('news'),
  source('source'),
  qa('qa');

  final String value;
  const AiMode(this.value);

  static AiMode fromString(String value) {
    return AiMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AiMode.qa,
    );
  }
}

/// FieldContent model for individual streaming field content.
class FieldContent {
  const FieldContent({required this.text, required this.state});

  factory FieldContent.fromJson(Map<String, dynamic> json) {
    return FieldContent(
      text: json['text'] as String,
      state: FieldState.fromString(json['state'] as String),
    );
  }
  final String text;
  final FieldState state;

  Map<String, dynamic> toJson() {
    return {'text': text, 'state': state.value};
  }

  FieldContent copyWith({String? text, FieldState? state}) {
    return FieldContent(text: text ?? this.text, state: state ?? this.state);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FieldContent) return false;
    return text == other.text && state == other.state;
  }

  @override
  int get hashCode => Object.hash(text, state);
}

/// AiResponseContent model containing multiple fields.
class AiResponseContent {
  const AiResponseContent({required this.fields});

  factory AiResponseContent.fromJson(Map<String, dynamic> json) {
    final fieldsJson = json['fields'] as Map<String, dynamic>? ?? {};
    return AiResponseContent(
      fields: fieldsJson.map(
        (key, value) =>
            MapEntry(key, FieldContent.fromJson(value as Map<String, dynamic>)),
      ),
    );
  }
  final Map<String, FieldContent> fields;

  Map<String, dynamic> toJson() {
    return {
      'fields': fields.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  AiResponseContent copyWith({Map<String, FieldContent>? fields}) {
    return AiResponseContent(fields: fields ?? this.fields);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AiResponseContent) return false;
    return _mapEquals(fields, other.fields);
  }

  @override
  int get hashCode =>
      Object.hashAll(fields.entries.map((e) => Object.hash(e.key, e.value)));

  static bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

/// AiMessage model representing a message in the AI conversation.
class AiMessage {
  const AiMessage({
    required this.id,
    required this.role,
    required this.timestamp,
    required this.state,
    this.userText,
    this.content,
  });

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
      id: json['id'] as String,
      role: MessageRole.fromString(json['role'] as String),
      userText: json['user_text'] as String?,
      content: json['content'] != null
          ? AiResponseContent.fromJson(json['content'] as Map<String, dynamic>)
          : null,
      timestamp: DateTime.parse(json['timestamp'] as String),
      state: AiMessageState.fromString(json['state'] as String),
    );
  }
  final String id;
  final MessageRole role;
  final String? userText;
  final AiResponseContent? content;
  final DateTime timestamp;
  final AiMessageState state;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.value,
      'user_text': userText,
      'content': content?.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'state': state.value,
    };
  }

  AiMessage copyWith({
    String? id,
    MessageRole? role,
    String? userText,
    AiResponseContent? content,
    DateTime? timestamp,
    AiMessageState? state,
  }) {
    return AiMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      userText: userText ?? this.userText,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      state: state ?? this.state,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AiMessage) return false;
    return id == other.id &&
        role == other.role &&
        userText == other.userText &&
        content == other.content &&
        timestamp == other.timestamp &&
        state == other.state;
  }

  @override
  int get hashCode =>
      Object.hash(id, role, userText, content, timestamp, state);
}
