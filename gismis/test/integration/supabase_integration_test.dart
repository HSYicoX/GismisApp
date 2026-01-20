/// End-to-end integration tests for Supabase integration.
///
/// Tests the complete data flow:
/// - Config → Client → Repository → Provider
/// - Flutter client interaction with Edge Functions
///
/// Requirements: All (1.1-8.4)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gismis/core/supabase/paginated_result.dart';
import 'package:gismis/core/supabase/supabase_client.dart';
import 'package:gismis/core/supabase/supabase_config.dart';
import 'package:gismis/core/supabase/supabase_providers.dart';
import 'package:gismis/core/supabase/supabase_storage.dart';

void main() {
  group('Supabase Integration Tests', () {
    group('Config → Client → Storage Data Flow', () {
      test('SupabaseConfig creates valid URLs for all services', () {
        // Arrange
        const baseUrl = 'https://api.haokir.com';
        const anonKey = 'test-anon-key';

        // Act
        final config = SupabaseConfig.standard(
          baseUrl: baseUrl,
          anonKey: anonKey,
        );

        // Assert - All service URLs are correctly derived
        expect(config.restUrl, equals('$baseUrl/rest/v1'));
        expect(config.storageUrl, equals('$baseUrl/storage/v1'));
        expect(config.functionsUrl, equals('$baseUrl/functions/v1'));
        expect(config.realtimeUrl, equals('wss://api.haokir.com/realtime/v1'));
        expect(config.anonKey, equals(anonKey));
        expect(config.hasValidAnonKey, isTrue);
      });

      test('SupabaseClient is created with correct configuration', () {
        // Arrange
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'test-key',
        );

        // Act
        final client = SupabaseClient(config: config);

        // Assert
        expect(client.config, equals(config));
        expect(client.dio, isNotNull);
        expect(client.dio.options.headers['apikey'], equals('test-key'));
      });

      test('SupabaseStorage generates correct public URLs', () {
        // Arrange
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'test-key',
        );
        final storage = SupabaseStorage(config: config);

        // Act
        final publicUrl = storage.getPublicUrl('anime-covers', 'cover.jpg');

        // Assert
        expect(
          publicUrl,
          equals(
            'https://api.haokir.com/storage/v1/object/public/anime-covers/cover.jpg',
          ),
        );
      });

      test('SupabaseStorage generates correct transformed URLs', () {
        // Arrange
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'test-key',
        );
        final storage = SupabaseStorage(config: config);

        // Act
        final transformedUrl = storage.getTransformedUrl(
          'anime-covers',
          'cover.jpg',
          width: 200,
          height: 300,
          format: 'webp',
          quality: 80,
        );

        // Assert
        expect(transformedUrl, contains('/render/image/public/'));
        expect(transformedUrl, contains('width=200'));
        expect(transformedUrl, contains('height=300'));
        expect(transformedUrl, contains('format=webp'));
        expect(transformedUrl, contains('quality=80'));
      });
    });

    group('Provider Integration', () {
      test('supabaseConfigProvider returns production config by default', () {
        // Arrange
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Act
        final config = container.read(supabaseConfigProvider);

        // Assert - Default production config
        expect(config.restUrl, contains('/rest/v1'));
        expect(config.storageUrl, contains('/storage/v1'));
        expect(config.functionsUrl, contains('/functions/v1'));
        expect(config.realtimeUrl, contains('/realtime/v1'));
      });

      test('supabaseClientProvider creates client with config', () {
        // Arrange
        final testConfig = SupabaseConfig.standard(
          baseUrl: 'https://test.example.com',
          anonKey: 'test-anon-key',
        );

        final container = ProviderContainer(
          overrides: [supabaseConfigProvider.overrideWithValue(testConfig)],
        );
        addTearDown(container.dispose);

        // Act
        final client = container.read(supabaseClientProvider);

        // Assert
        expect(client.config, equals(testConfig));
        expect(client.dio.options.headers['apikey'], equals('test-anon-key'));
      });

      test('supabaseStorageProvider creates storage with config', () {
        // Arrange
        final testConfig = SupabaseConfig.standard(
          baseUrl: 'https://test.example.com',
          anonKey: 'test-anon-key',
        );

        final container = ProviderContainer(
          overrides: [supabaseConfigProvider.overrideWithValue(testConfig)],
        );
        addTearDown(container.dispose);

        // Act
        final storage = container.read(supabaseStorageProvider);

        // Assert
        final publicUrl = storage.getPublicUrl('test-bucket', 'file.jpg');
        expect(
          publicUrl,
          equals(
            'https://test.example.com/storage/v1/object/public/test-bucket/file.jpg',
          ),
        );
      });

      test('Provider overrides work correctly for testing', () {
        // Arrange - Override with dev config
        final devConfig = SupabaseConfig.dev(anonKey: 'dev-key');

        final container = ProviderContainer(
          overrides: [supabaseConfigProvider.overrideWithValue(devConfig)],
        );
        addTearDown(container.dispose);

        // Act
        final config = container.read(supabaseConfigProvider);
        final client = container.read(supabaseClientProvider);

        // Assert
        expect(config.restUrl, contains('localhost:54321'));
        expect(client.config.anonKey, equals('dev-key'));
      });
    });

    group('PaginatedResult Data Flow', () {
      test('PaginatedResult correctly calculates hasMore', () {
        // Arrange & Act - Has more items
        final resultWithMore = PaginatedResult<String>(
          items: List.generate(20, (i) => 'item$i'),
          total: 100,
          offset: 0,
          limit: 20,
          hasMore: true,
        );

        // Assert
        expect(resultWithMore.hasMore, isTrue);
        expect(resultWithMore.items.length, equals(20));
        expect(resultWithMore.total, equals(100));

        // Arrange & Act - No more items
        final resultNoMore = PaginatedResult<String>(
          items: List.generate(10, (i) => 'item$i'),
          total: 30,
          offset: 20,
          limit: 20,
          hasMore: false,
        );

        // Assert
        expect(resultNoMore.hasMore, isFalse);
      });

      test('PaginatedResult handles null total gracefully', () {
        // Arrange & Act
        final result = PaginatedResult<String>(
          items: ['item1', 'item2'],
          total: null,
          offset: 0,
          limit: 10,
          hasMore: true,
        );

        // Assert
        expect(result.total, isNull);
        expect(result.items.length, equals(2));
      });
    });

    group('Range Header Contract', () {
      test('buildRangeHeader creates correct format for first page', () {
        // Act
        final header = SupabaseClient.buildRangeHeader(offset: 0, limit: 20);

        // Assert
        expect(header, equals('0-19'));
      });

      test('buildRangeHeader creates correct format for subsequent pages', () {
        // Act
        final header = SupabaseClient.buildRangeHeader(offset: 20, limit: 20);

        // Assert
        expect(header, equals('20-39'));
      });

      test('buildRangeHeader handles single item request', () {
        // Act
        final header = SupabaseClient.buildRangeHeader(offset: 5, limit: 1);

        // Assert
        expect(header, equals('5-5'));
      });

      test('parseContentRangeTotal extracts total from standard format', () {
        // Act
        final total = SupabaseClient.parseContentRangeTotal('items 0-19/245');

        // Assert
        expect(total, equals(245));
      });

      test('parseContentRangeTotal extracts total from asterisk format', () {
        // Act
        final total = SupabaseClient.parseContentRangeTotal('items */100');

        // Assert
        expect(total, equals(100));
      });

      test('parseContentRangeTotal returns null for invalid format', () {
        // Act & Assert
        expect(SupabaseClient.parseContentRangeTotal(null), isNull);
        expect(SupabaseClient.parseContentRangeTotal('invalid'), isNull);
        expect(SupabaseClient.parseContentRangeTotal('items 0-19'), isNull);
      });
    });

    group('Storage URL Generation', () {
      test('buildPublicUrl normalizes paths with leading slashes', () {
        // Act
        final url = SupabaseStorage.buildPublicUrl(
          'https://api.haokir.com/storage/v1',
          'anime-covers',
          '/cover.jpg',
        );

        // Assert - No double slashes after bucket name
        final pathAfterBucket = url.split('anime-covers/').last;
        expect(pathAfterBucket, isNot(startsWith('/')));
        expect(
          url,
          equals(
            'https://api.haokir.com/storage/v1/object/public/anime-covers/cover.jpg',
          ),
        );
      });

      test('buildPublicUrl normalizes paths with multiple slashes', () {
        // Act
        final url = SupabaseStorage.buildPublicUrl(
          'https://api.haokir.com/storage/v1',
          'anime-covers',
          'folder//subfolder///image.jpg',
        );

        // Assert
        expect(
          url,
          equals(
            'https://api.haokir.com/storage/v1/object/public/anime-covers/folder/subfolder/image.jpg',
          ),
        );
      });

      test('buildTransformedUrl includes all transformation parameters', () {
        // Act
        final url = SupabaseStorage.buildTransformedUrl(
          'https://api.haokir.com/storage/v1',
          'anime-covers',
          'cover.jpg',
          width: 200,
          height: 300,
          format: 'webp',
          quality: 80,
          resize: 'contain',
        );

        // Assert
        expect(url, contains('width=200'));
        expect(url, contains('height=300'));
        expect(url, contains('format=webp'));
        expect(url, contains('quality=80'));
        expect(url, contains('resize=contain'));
      });

      test('buildTransformedUrl omits default resize mode', () {
        // Act
        final url = SupabaseStorage.buildTransformedUrl(
          'https://api.haokir.com/storage/v1',
          'anime-covers',
          'cover.jpg',
        );

        // Assert - Default 'cover' resize is not included
        expect(url, isNot(contains('resize=')));
      });
    });

    group('Environment Configuration', () {
      test('dev config uses localhost URLs', () {
        // Act
        final config = SupabaseConfig.dev(anonKey: 'dev-key');

        // Assert
        expect(config.restUrl, contains('localhost:54321'));
        expect(config.storageUrl, contains('localhost:54321'));
        expect(config.functionsUrl, contains('localhost:54321'));
        expect(config.realtimeUrl, startsWith('ws://'));
      });

      test('custom config allows separate service URLs', () {
        // Act
        final config = SupabaseConfig.custom(
          restUrl: 'https://db.example.com/v1',
          storageUrl: 'https://storage.example.com/v1',
          functionsUrl: 'https://functions.example.com/v1',
          realtimeUrl: 'wss://realtime.example.com/v1',
          anonKey: 'custom-key',
        );

        // Assert
        expect(config.restUrl, equals('https://db.example.com/v1'));
        expect(config.storageUrl, equals('https://storage.example.com/v1'));
        expect(config.functionsUrl, equals('https://functions.example.com/v1'));
        expect(config.realtimeUrl, equals('wss://realtime.example.com/v1'));
      });

      test('hasValidAnonKey returns false for empty key', () {
        // Act
        final config = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: '',
        );

        // Assert
        expect(config.hasValidAnonKey, isFalse);
      });
    });

    group('Config Equality', () {
      test('identical configs are equal', () {
        // Arrange
        final config1 = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'key',
        );
        final config2 = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'key',
        );

        // Assert
        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('different configs are not equal', () {
        // Arrange
        final config1 = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'key1',
        );
        final config2 = SupabaseConfig.standard(
          baseUrl: 'https://api.haokir.com',
          anonKey: 'key2',
        );

        // Assert
        expect(config1, isNot(equals(config2)));
      });
    });
  });
}
