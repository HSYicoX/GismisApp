import 'dart:convert';

import 'package:gismis/core/network/sse_event.dart';
import 'package:glados/glados.dart';

/// Feature: anime-tracker-app, Property 20: SSE Event Parsing
/// Validates: Requirements 10.6
///
/// For any valid SSE event string matching the protocol (meta, field_start,
/// delta, field_end, done, error), parsing SHALL produce the correct SSEEvent
/// subtype with correct field values.

void main() {
  group('Property 20: SSE Event Parsing', () {
    // Helper to create raw SSE event string
    String createRawEvent(String eventType, Map<String, dynamic> data) {
      return 'event: $eventType\ndata: ${jsonEncode(data)}';
    }

    Glados2<String, List<String>>(
      any.nonEmptyLetterOrDigits,
      any.list(any.nonEmptyLetterOrDigits),
    ).test(
      'For any meta event with messageId and fields, parsing produces SSEMetaEvent with correct values',
      (messageId, fields) {
        final rawEvent = createRawEvent('meta', {
          'message_id': messageId,
          'fields': fields,
        });

        final parsed = SSEEvent.parse(rawEvent);

        expect(parsed, isA<SSEMetaEvent>());
        final metaEvent = parsed! as SSEMetaEvent;
        expect(metaEvent.messageId, equals(messageId));
        expect(metaEvent.fields, equals(fields));
      },
    );

    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any field_start event with field name, parsing produces SSEFieldStartEvent with correct field',
      (fieldName) {
        final rawEvent = createRawEvent('field_start', {'field': fieldName});

        final parsed = SSEEvent.parse(rawEvent);

        expect(parsed, isA<SSEFieldStartEvent>());
        final fieldStartEvent = parsed! as SSEFieldStartEvent;
        expect(fieldStartEvent.field, equals(fieldName));
      },
    );

    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.letterOrDigits, // Allow empty text for delta
    ).test(
      'For any delta event with field and text, parsing produces SSEDeltaEvent with correct values',
      (fieldName, text) {
        final rawEvent = createRawEvent('delta', {
          'field': fieldName,
          'text': text,
        });

        final parsed = SSEEvent.parse(rawEvent);

        expect(parsed, isA<SSEDeltaEvent>());
        final deltaEvent = parsed! as SSEDeltaEvent;
        expect(deltaEvent.field, equals(fieldName));
        expect(deltaEvent.text, equals(text));
      },
    );

    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any field_end event with field name, parsing produces SSEFieldEndEvent with correct field',
      (fieldName) {
        final rawEvent = createRawEvent('field_end', {'field': fieldName});

        final parsed = SSEEvent.parse(rawEvent);

        expect(parsed, isA<SSEFieldEndEvent>());
        final fieldEndEvent = parsed! as SSEFieldEndEvent;
        expect(fieldEndEvent.field, equals(fieldName));
      },
    );

    test('Done event parsing produces SSEDoneEvent', () {
      final rawEvent = createRawEvent('done', {});

      final parsed = SSEEvent.parse(rawEvent);

      expect(parsed, isA<SSEDoneEvent>());
    });

    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any error event with message, parsing produces SSEErrorEvent with correct message',
      (message) {
        final rawEvent = createRawEvent('error', {'message': message});

        final parsed = SSEEvent.parse(rawEvent);

        expect(parsed, isA<SSEErrorEvent>());
        final errorEvent = parsed! as SSEErrorEvent;
        expect(errorEvent.message, equals(message));
      },
    );

    // Test that parsing is deterministic (same input always produces same output)
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any valid event, parsing the same input twice produces equal results',
      (fieldName, text) {
        final rawEvent = createRawEvent('delta', {
          'field': fieldName,
          'text': text,
        });

        final parsed1 = SSEEvent.parse(rawEvent);
        final parsed2 = SSEEvent.parse(rawEvent);

        expect(parsed1, equals(parsed2));
      },
    );

    // Test edge cases
    test('Empty string returns null', () {
      expect(SSEEvent.parse(''), isNull);
    });

    test('Whitespace only returns null', () {
      expect(SSEEvent.parse('   \n\t  '), isNull);
    });

    test('Missing event type returns null', () {
      expect(SSEEvent.parse('data: {"field": "test"}'), isNull);
    });

    test('Missing data returns null', () {
      expect(SSEEvent.parse('event: delta'), isNull);
    });

    test('Invalid JSON in data returns null for non-error events', () {
      expect(SSEEvent.parse('event: delta\ndata: not json'), isNull);
    });

    test(
      'Invalid JSON in error event returns SSEErrorEvent with raw message',
      () {
        final parsed = SSEEvent.parse('event: error\ndata: Connection failed');
        expect(parsed, isA<SSEErrorEvent>());
        expect((parsed! as SSEErrorEvent).message, equals('Connection failed'));
      },
    );

    test('Unknown event type returns null', () {
      final rawEvent = createRawEvent('unknown_type', {'data': 'test'});
      expect(SSEEvent.parse(rawEvent), isNull);
    });
  });
}
