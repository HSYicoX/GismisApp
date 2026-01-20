import 'package:flutter_test/flutter_test.dart';
import 'package:gismis/core/supabase/supabase_config.dart';

/// Unit tests for SupabaseConfig.
///
/// Tests environment configuration loading and URL format correctness.
/// _Requirements: 1.1, 1.5_
void main() {
  group('SupabaseConfig', () {
    group('standard factory', () {
      test('creates config with correct URL paths', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.example.com',
          anonKey: 'test-anon-key',
        );

        expect(config.restUrl, equals('https://api.example.com/rest/v1'));
        expect(config.storageUrl, equals('https://api.example.com/storage/v1'));
        expect(
          config.functionsUrl,
          equals('https://api.example.com/functions/v1'),
        );
        expect(config.realtimeUrl, equals('wss://api.example.com/realtime/v1'));
        expect(config.anonKey, equals('test-anon-key'));
      });

      test('handles trailing slash in baseUrl', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.example.com/',
          anonKey: 'test-key',
        );

        expect(config.restUrl, equals('https://api.example.com/rest/v1'));
        expect(config.storageUrl, equals('https://api.example.com/storage/v1'));
      });

      test('uses ws scheme for http baseUrl', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'http://localhost:54321',
          anonKey: 'local-key',
        );

        expect(config.realtimeUrl, equals('ws://localhost/realtime/v1'));
      });

      test('uses wss scheme for https baseUrl', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.example.com',
          anonKey: 'test-key',
        );

        expect(config.realtimeUrl, equals('wss://api.example.com/realtime/v1'));
      });
    });

    group('custom factory', () {
      test('creates config with custom URLs', () {
        final config = SupabaseConfig.custom(
          restUrl: 'https://db.example.com/v1',
          storageUrl: 'https://storage.example.com/v1',
          functionsUrl: 'https://functions.example.com/v1',
          realtimeUrl: 'wss://realtime.example.com/v1',
          anonKey: 'custom-key',
        );

        expect(config.restUrl, equals('https://db.example.com/v1'));
        expect(config.storageUrl, equals('https://storage.example.com/v1'));
        expect(config.functionsUrl, equals('https://functions.example.com/v1'));
        expect(config.realtimeUrl, equals('wss://realtime.example.com/v1'));
        expect(config.anonKey, equals('custom-key'));
      });
    });

    group('dev factory', () {
      test('creates config with localhost URLs', () {
        final config = SupabaseConfig.dev(anonKey: 'dev-key');

        expect(config.restUrl, equals('http://localhost:54321/rest/v1'));
        expect(config.storageUrl, equals('http://localhost:54321/storage/v1'));
        expect(
          config.functionsUrl,
          equals('http://localhost:54321/functions/v1'),
        );
        expect(config.realtimeUrl, equals('ws://localhost/realtime/v1'));
        expect(config.anonKey, equals('dev-key'));
      });
    });

    group('hasValidAnonKey', () {
      test('returns true when anonKey is not empty', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.example.com',
          anonKey: 'valid-key',
        );

        expect(config.hasValidAnonKey, isTrue);
      });

      test('returns false when anonKey is empty', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.example.com',
          anonKey: '',
        );

        expect(config.hasValidAnonKey, isFalse);
      });
    });

    group('equality', () {
      test('two configs with same values are equal', () {
        final config1 = SupabaseConfig.standard(
          baseUrl: 'https://api.example.com',
          anonKey: 'test-key',
        );
        final config2 = SupabaseConfig.standard(
          baseUrl: 'https://api.example.com',
          anonKey: 'test-key',
        );

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('two configs with different values are not equal', () {
        final config1 = SupabaseConfig.standard(
          baseUrl: 'https://api.example.com',
          anonKey: 'key-1',
        );
        final config2 = SupabaseConfig.standard(
          baseUrl: 'https://api.example.com',
          anonKey: 'key-2',
        );

        expect(config1, isNot(equals(config2)));
      });
    });

    group('toString', () {
      test('does not expose full anonKey', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.example.com',
          anonKey: 'secret-anon-key-12345',
        );

        final str = config.toString();

        expect(str, contains('hasAnonKey: true'));
        expect(str, isNot(contains('secret-anon-key-12345')));
      });

      test('shows hasAnonKey: false when empty', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.example.com',
          anonKey: '',
        );

        expect(config.toString(), contains('hasAnonKey: false'));
      });
    });
  });
}
