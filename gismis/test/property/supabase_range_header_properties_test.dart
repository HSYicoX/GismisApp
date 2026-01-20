import 'package:glados/glados.dart';
import 'package:gismis/core/supabase/supabase_client.dart';

/// Feature: supabase-integration, Property 1: Range header format correctness
/// Validates: Requirements 2.4
///
/// For any valid offset and limit values, the Range header SHALL be formatted
/// as "start-end" where start = offset and end = offset + limit - 1.

void main() {
  group('Property 1: Range header format correctness', () {
    Glados2<int, int>(any.intInRange(0, 1000), any.intInRange(1, 100)).test(
      'For any offset >= 0 and limit > 0, Range header format is "start-end"',
      (int offset, int limit) {
        final header = SupabaseClient.buildRangeHeader(
          offset: offset,
          limit: limit,
        );

        // Verify format matches "start-end"
        final parts = header.split('-');
        expect(
          parts.length,
          equals(2),
          reason: 'Header should have format "start-end"',
        );

        final start = int.parse(parts[0]);
        final end = int.parse(parts[1]);

        // Verify start equals offset
        expect(start, equals(offset), reason: 'Start should equal offset');

        // Verify end equals offset + limit - 1
        expect(
          end,
          equals(offset + limit - 1),
          reason: 'End should equal offset + limit - 1',
        );

        // Verify end >= start (valid range)
        expect(
          end,
          greaterThanOrEqualTo(start),
          reason: 'End should be >= start',
        );
      },
    );

    Glados<int>(any.intInRange(0, 100)).test(
      'For any offset with limit=1, Range header is "offset-offset"',
      (int offset) {
        final header = SupabaseClient.buildRangeHeader(
          offset: offset,
          limit: 1,
        );

        expect(header, equals('$offset-$offset'));
      },
    );

    Glados<int>(any.intInRange(1, 50)).test(
      'For offset=0 and any limit, Range header starts with "0-"',
      (int limit) {
        final header = SupabaseClient.buildRangeHeader(offset: 0, limit: limit);

        expect(header, startsWith('0-'));
        expect(header, equals('0-${limit - 1}'));
      },
    );
  });

  group('Content-Range parsing', () {
    Glados<int>(any.intInRange(0, 1000)).test(
      'For any total count, Content-Range parsing extracts correct total',
      (int total) {
        // Test standard format: "items 0-19/total"
        final header1 = 'items 0-19/$total';
        expect(
          SupabaseClient.parseContentRangeTotal(header1),
          equals(total),
          reason: 'Should parse total from standard format',
        );

        // Test format with asterisk: "items */total"
        final header2 = 'items */$total';
        expect(
          SupabaseClient.parseContentRangeTotal(header2),
          equals(total),
          reason: 'Should parse total from asterisk format',
        );
      },
    );

    test('parseContentRangeTotal returns null for null input', () {
      expect(SupabaseClient.parseContentRangeTotal(null), isNull);
    });

    test('parseContentRangeTotal returns null for malformed input', () {
      expect(SupabaseClient.parseContentRangeTotal('invalid'), isNull);
      expect(SupabaseClient.parseContentRangeTotal('items 0-19'), isNull);
      expect(SupabaseClient.parseContentRangeTotal(''), isNull);
    });
  });
}
