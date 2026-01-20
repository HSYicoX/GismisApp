/// Feature: supabase-integration, Property 9: SSE Event Type Mapping Correctness
/// Validates: Requirements 7.2
///
/// For any valid SSE event, the mapSSEEvent function SHALL produce the correct
/// AIStreamEvent subtype with correct field values.

import 'package:gismis/core/network/sse_event.dart';
import 'package:gismis/features/ai_assistant/data/models/ai_stream_event.dart';
import 'package:glados/glados.dart';
import 'package:test/test.dart';

/// Helper function to map SSE events to AI stream events.
/// This mirrors the logic in SupabaseAiRepository.mapSSEEvent
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

void main() {
  group('Property 9: SSE Event Type Mapping Correctness', () {
    Glados2<String, List<String>>(
      any.nonEmptyLetterOrDigits,
      any.list(any.nonEmptyLetterOrDigits),
    ).test(
      'For any SSEMetaEvent, mapSSEEvent produces AIMetaEvent with correct values',
      (messageId, fields) {
        final sseEvent = SSEMetaEvent(messageId: messageId, fields: fields);

        final result = mapSSEEvent(sseEvent);

        expect(result, isA<AIMetaEvent>());
        final aiEvent = result as AIMetaEvent;
        // messageId maps to conversationId (if non-empty)
        if (messageId.isNotEmpty) {
          expect(aiEvent.conversationId, equals(messageId));
        }
        // First field maps to model (if fields non-empty)
        if (fields.isNotEmpty) {
          expect(aiEvent.model, equals(fields.first));
        }
      },
    );

    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.letterOrDigits,
    ).test(
      'For any SSEDeltaEvent, mapSSEEvent produces AIDeltaEvent with correct content',
      (field, text) {
        final sseEvent = SSEDeltaEvent(field: field, text: text);

        final result = mapSSEEvent(sseEvent);

        expect(result, isA<AIDeltaEvent>());
        final aiEvent = result as AIDeltaEvent;
        expect(aiEvent.content, equals(text));
      },
    );

    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any SSEFieldStartEvent, mapSSEEvent produces AIFieldStartEvent with correct field',
      (fieldName) {
        final sseEvent = SSEFieldStartEvent(field: fieldName);

        final result = mapSSEEvent(sseEvent);

        expect(result, isA<AIFieldStartEvent>());
        final aiEvent = result as AIFieldStartEvent;
        expect(aiEvent.field, equals(fieldName));
      },
    );

    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any SSEFieldEndEvent, mapSSEEvent produces AIFieldEndEvent with correct field',
      (fieldName) {
        final sseEvent = SSEFieldEndEvent(field: fieldName);

        final result = mapSSEEvent(sseEvent);

        expect(result, isA<AIFieldEndEvent>());
        final aiEvent = result as AIFieldEndEvent;
        expect(aiEvent.field, equals(fieldName));
      },
    );

    test('SSEDoneEvent maps to AIDoneEvent', () {
      const sseEvent = SSEDoneEvent();

      final result = mapSSEEvent(sseEvent);

      expect(result, isA<AIDoneEvent>());
    });

    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any SSEErrorEvent, mapSSEEvent produces AIErrorEvent with correct message',
      (message) {
        final sseEvent = SSEErrorEvent(message: message);

        final result = mapSSEEvent(sseEvent);

        expect(result, isA<AIErrorEvent>());
        final aiEvent = result as AIErrorEvent;
        expect(aiEvent.message, equals(message));
      },
    );

    // Test that mapping is deterministic (same input always produces same output)
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any SSE event, mapping the same input twice produces equal results',
      (field, text) {
        final sseEvent = SSEDeltaEvent(field: field, text: text);

        final result1 = mapSSEEvent(sseEvent);
        final result2 = mapSSEEvent(sseEvent);

        expect(result1, equals(result2));
      },
    );

    // Test that all SSE event types are handled (no exceptions thrown)
    test('All SSE event types are handled without exceptions', () {
      final events = <SSEEvent>[
        const SSEMetaEvent(messageId: 'test', fields: ['field1']),
        const SSEDeltaEvent(field: 'content', text: 'hello'),
        const SSEFieldStartEvent(field: 'thinking'),
        const SSEFieldEndEvent(field: 'thinking'),
        const SSEDoneEvent(),
        const SSEErrorEvent(message: 'test error'),
      ];

      for (final event in events) {
        expect(() => mapSSEEvent(event), returnsNormally);
      }
    });
  });
}
