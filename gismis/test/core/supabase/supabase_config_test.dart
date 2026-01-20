import 'package:flutter_test/flutter_test.dart';
import 'package:gismis/core/supabase/supabase_config.dart';

/// Unit tests for SupabaseConfig.
///
/// Validates: Requirements 1.1, 1.2, 1.3, 1.5
void main() {
  group('SupabaseConfig', () {
    group('standard factory', () {
      test('creates correct URLs from base URL', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'test-anon-key',
        );

        expect(config.restUrl, equals('https://api.haokir.com/rest/v1'));
        expect(config.storageUrl, equals('https://api.haokir.com/storage/v1'));
        expect(
          config.functionsUrl,
          equals('https://api.haokir.com/functions/v1'),
        );
        expect(config.realtimeUrl, equals('wss://api.haokir.com/realtime/v1'));
        expect(config.anonKey, equals('test-anon-key'));
      });

      test('handles trailing slash in base URL', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com/',
          anonKey: 'test-key',
        );

        expect(config.restUrl, equals('https://api.haokir.com/rest/v1'));
        expect(config.storageUrl, equals('https://api.haokir.com/storage/v1'));
      });

      test('extracts host correctly for realtime URL', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://my-project.supabase.co',
          anonKey: 'key',
        );

        expect(
          config.realtimeUrl,
          equals('wss://my-project.supabase.co/realtime/v1'),
        );
      });

      test('handles port in base URL', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'http://localhost:54321',
          anonKey: 'local-key',
        );

        expect(config.restUrl, equals('http://localhost:54321/rest/v1'));
        // ws:// for http, wss:// for https
        expect(config.realtimeUrl, equals('ws://localhost/realtime/v1'));
      });
    });

    group('custom factory', () {
      test('uses provided URLs directly', () {
        final config = SupabaseConfig.custom(
          restUrl: 'https://rest.example.com/v1',
          storageUrl: 'https://storage.example.com/v1',
          functionsUrl: 'https://functions.example.com/v1',
          realtimeUrl: 'wss://realtime.example.com/v1',
          anonKey: 'custom-key',
        );

        expect(config.restUrl, equals('https://rest.example.com/v1'));
        expect(config.storageUrl, equals('https://storage.example.com/v1'));
        expect(config.functionsUrl, equals('https://functions.example.com/v1'));
        expect(config.realtimeUrl, equals('wss://realtime.example.com/v1'));
        expect(config.anonKey, equals('custom-key'));
      });
    });

    group('hasValidAnonKey', () {
      test('returns true when anonKey is not empty', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'valid-key',
        );

        expect(config.hasValidAnonKey, isTrue);
      });

      test('returns false when anonKey is empty', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: '',
        );

        expect(config.hasValidAnonKey, isFalse);
      });
    });

    group('equality', () {
      test('equal configs have same hashCode', () {
        final config1 = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'key',
        );
        final config2 = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'key',
        );

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('different configs are not equal', () {
        final config1 = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'key1',
        );
        final config2 = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'key2',
        );

        expect(config1, isNot(equals(config2)));
      });
    });

    group('toString', () {
      test('returns readable string with URL information', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'secret-key',
        );

        final str = config.toString();

        expect(str, contains('restUrl'));
        expect(str, contains('storageUrl'));
        expect(str, contains('functionsUrl'));
        expect(str, contains('realtimeUrl'));
        expect(str, contains('hasAnonKey'));
      });
    });

    group('URL format validation', () {
      test('restUrl ends with /rest/v1 for standard config', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'key',
        );

        expect(config.restUrl, endsWith('/rest/v1'));
      });

      test('storageUrl ends with /storage/v1 for standard config', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'key',
        );

        expect(config.storageUrl, endsWith('/storage/v1'));
      });

      test('functionsUrl ends with /functions/v1 for standard config', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'key',
        );

        expect(config.functionsUrl, endsWith('/functions/v1'));
      });

      test('realtimeUrl starts with wss:// for standard config', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'key',
        );

        expect(config.realtimeUrl, startsWith('wss://'));
      });

      test('realtimeUrl ends with /realtime/v1 for standard config', () {
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'key',
        );

        expect(config.realtimeUrl, endsWith('/realtime/v1'));
      });
    });
  });
}
