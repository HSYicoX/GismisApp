import 'package:gismis/shared/models/ai_message.dart';
import 'package:glados/glados.dart';

/// Feature: anime-tracker-app, Property 8: SSE Field State Machine
/// Validates: Requirements 4.4, 4.5, 4.6
///
/// For any sequence of SSE events for a field (field_start → delta* → field_end),
/// the field state SHALL transition: hidden → skeleton → blurred (on field_start)
/// → blurred (during deltas) → clear (on field_end). The accumulated text SHALL
/// equal the concatenation of all delta texts.

/// Simulates the field state machine transitions.
class FieldStateMachine {
  FieldStateMachine(this.fieldName);

  final String fieldName;
  FieldState _state = FieldState.hidden;
  String _accumulatedText = '';

  FieldState get state => _state;
  String get accumulatedText => _accumulatedText;

  /// Initialize field (from meta event).
  void initialize() {
    _state = FieldState.skeleton;
    _accumulatedText = '';
  }

  /// Process field_start event.
  void onFieldStart() {
    if (_state == FieldState.skeleton) {
      _state = FieldState.blurred;
    }
  }

  /// Process delta event.
  void onDelta(String text) {
    if (_state == FieldState.blurred) {
      _accumulatedText += text;
    }
  }

  /// Process field_end event.
  void onFieldEnd() {
    if (_state == FieldState.blurred) {
      _state = FieldState.clear;
    }
  }

  /// Process done event.
  void onDone() {
    if (_state == FieldState.clear) {
      _state = FieldState.completed;
    }
  }
}

void main() {
  group('Property 8: SSE Field State Machine', () {
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any field, initial state after meta event is skeleton',
      (fieldName) {
        final machine = FieldStateMachine(fieldName);

        machine.initialize();

        expect(machine.state, equals(FieldState.skeleton));
        expect(machine.accumulatedText, isEmpty);
      },
    );

    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any field, state after field_start is blurred',
      (fieldName) {
        final machine = FieldStateMachine(fieldName);
        machine.initialize();

        machine.onFieldStart();

        expect(machine.state, equals(FieldState.blurred));
      },
    );

    Glados2<String, List<String>>(
      any.nonEmptyLetterOrDigits,
      any.list(any.letterOrDigits),
    ).test(
      'For any sequence of delta events, accumulated text equals concatenation of all deltas',
      (fieldName, deltaTexts) {
        final machine = FieldStateMachine(fieldName);
        machine.initialize();
        machine.onFieldStart();

        for (final text in deltaTexts) {
          machine.onDelta(text);
        }

        expect(machine.accumulatedText, equals(deltaTexts.join()));
        expect(machine.state, equals(FieldState.blurred));
      },
    );

    Glados2<String, List<String>>(
      any.nonEmptyLetterOrDigits,
      any.list(any.letterOrDigits),
    ).test('For any field, state after field_end is clear', (
      fieldName,
      deltaTexts,
    ) {
      final machine = FieldStateMachine(fieldName);
      machine.initialize();
      machine.onFieldStart();
      for (final text in deltaTexts) {
        machine.onDelta(text);
      }

      machine.onFieldEnd();

      expect(machine.state, equals(FieldState.clear));
    });

    Glados2<String, List<String>>(
      any.nonEmptyLetterOrDigits,
      any.list(any.letterOrDigits),
    ).test(
      'For any complete field sequence, final state after done is completed',
      (fieldName, deltaTexts) {
        final machine = FieldStateMachine(fieldName);
        machine.initialize();
        machine.onFieldStart();
        for (final text in deltaTexts) {
          machine.onDelta(text);
        }
        machine.onFieldEnd();

        machine.onDone();

        expect(machine.state, equals(FieldState.completed));
      },
    );

    Glados2<String, List<String>>(
      any.nonEmptyLetterOrDigits,
      any.list(any.letterOrDigits),
    ).test(
      'For any complete sequence, text is preserved through all state transitions',
      (fieldName, deltaTexts) {
        final machine = FieldStateMachine(fieldName);
        final expectedText = deltaTexts.join();

        // Full sequence: initialize → field_start → deltas → field_end → done
        machine.initialize();
        machine.onFieldStart();
        for (final text in deltaTexts) {
          machine.onDelta(text);
        }
        machine.onFieldEnd();
        machine.onDone();

        expect(machine.accumulatedText, equals(expectedText));
        expect(machine.state, equals(FieldState.completed));
      },
    );

    // Test state transition order is enforced
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'Delta events before field_start do not accumulate text',
      (fieldName) {
        final machine = FieldStateMachine(fieldName);
        machine.initialize();

        // Try to add delta before field_start
        machine.onDelta('should not accumulate');

        expect(machine.accumulatedText, isEmpty);
        expect(machine.state, equals(FieldState.skeleton));
      },
    );

    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'field_end before field_start does not change state',
      (fieldName) {
        final machine = FieldStateMachine(fieldName);
        machine.initialize();

        machine.onFieldEnd();

        expect(machine.state, equals(FieldState.skeleton));
      },
    );

    // Test FieldContent model
    Glados2<String, FieldState>(
      any.letterOrDigits,
      any.choose(FieldState.values),
    ).test('FieldContent copyWith preserves unchanged fields', (text, state) {
      final original = FieldContent(text: text, state: state);

      final copied = original.copyWith();

      expect(copied.text, equals(original.text));
      expect(copied.state, equals(original.state));
      expect(copied, equals(original));
    });

    Glados3<String, FieldState, String>(
      any.letterOrDigits,
      any.choose(FieldState.values),
      any.letterOrDigits,
    ).test('FieldContent copyWith updates specified fields', (
      text,
      state,
      newText,
    ) {
      final original = FieldContent(text: text, state: state);

      final copied = original.copyWith(text: newText);

      expect(copied.text, equals(newText));
      expect(copied.state, equals(state));
    });
  });
}
