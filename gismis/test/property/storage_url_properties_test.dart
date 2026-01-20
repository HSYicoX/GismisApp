import 'package:glados/glados.dart';
import 'package:gismis/core/supabase/supabase_storage.dart';

/// Feature: supabase-integration, Property 3: Storage URL format correctness
/// Validates: Requirements 8.1, 8.2, 8.4
///
/// For any valid storage URL, bucket name, and file path:
/// - Public URLs SHALL follow the format: {storageUrl}/object/public/{bucket}/{path}
/// - Transformed URLs SHALL follow the format: {storageUrl}/render/image/public/{bucket}/{path}?{params}
/// - URLs SHALL properly handle path normalization (leading slashes, multiple slashes)

void main() {
  group('Property 3: Storage URL format correctness', () {
    // Custom generators for valid bucket names and paths
    final bucketGen = any.choose([
      'anime-covers',
      'anime-banners',
      'user-avatars',
      'test-bucket',
    ]);

    final pathGen = any.choose([
      'image.jpg',
      'folder/image.png',
      'deep/nested/path/file.webp',
      'abc123/avatar.gif',
      'cover.jpeg',
    ]);

    final storageUrlGen = any.choose([
      'https://api.haokir.com/storage/v1',
      'https://example.com/storage/v1',
      'http://localhost:54321/storage/v1',
    ]);

    group('Public URL format', () {
      Glados3<String, String, String>(storageUrlGen, bucketGen, pathGen).test(
        'For any storageUrl, bucket, and path, public URL follows correct format',
        (storageUrl, bucket, path) {
          final url = SupabaseStorage.buildPublicUrl(storageUrl, bucket, path);

          // Verify URL starts with storage URL
          expect(url, startsWith(storageUrl));

          // Verify URL contains /object/public/ segment
          expect(url, contains('/object/public/'));

          // Verify URL contains bucket name
          expect(url, contains('/$bucket/'));

          // Verify URL ends with the path (normalized)
          final normalizedPath = path
              .replaceAll(RegExp(r'^/+'), '')
              .replaceAll(RegExp(r'/+'), '/');
          expect(url, endsWith(normalizedPath));

          // Verify complete format
          expect(
            url,
            equals('$storageUrl/object/public/$bucket/$normalizedPath'),
          );
        },
      );

      Glados<String>(bucketGen).test(
        'For any bucket, paths with leading slashes are normalized',
        (bucket) {
          const storageUrl = 'https://api.haokir.com/storage/v1';
          const pathWithSlash = '/image.jpg';

          final url = SupabaseStorage.buildPublicUrl(
            storageUrl,
            bucket,
            pathWithSlash,
          );

          // Should not have double slashes after bucket
          expect(url, isNot(contains('$bucket//')));

          // Should have correct format
          expect(url, equals('$storageUrl/object/public/$bucket/image.jpg'));
        },
      );

      Glados<String>(
        bucketGen,
      ).test('For any bucket, paths with multiple slashes are normalized', (
        bucket,
      ) {
        const storageUrl = 'https://api.haokir.com/storage/v1';
        const pathWithMultipleSlashes = 'folder//subfolder///image.jpg';

        final url = SupabaseStorage.buildPublicUrl(
          storageUrl,
          bucket,
          pathWithMultipleSlashes,
        );

        // Extract the path portion after the bucket to check for double slashes
        final pathPortion = url.split('/$bucket/').last;
        expect(pathPortion, isNot(contains('//')));

        // Should have normalized path
        expect(
          url,
          equals(
            '$storageUrl/object/public/$bucket/folder/subfolder/image.jpg',
          ),
        );
      });
    });

    group('Transformed URL format', () {
      final widthGen = any.intInRange(50, 2000);
      final heightGen = any.intInRange(50, 2000);
      final formatGen = any.choose(['webp', 'png', 'jpeg', 'avif']);
      final qualityGen = any.intInRange(1, 100);

      Glados3<String, String, String>(storageUrlGen, bucketGen, pathGen).test(
        'For any storageUrl, bucket, and path, transformed URL follows correct format',
        (storageUrl, bucket, path) {
          final url = SupabaseStorage.buildTransformedUrl(
            storageUrl,
            bucket,
            path,
          );

          // Verify URL starts with storage URL
          expect(url, startsWith(storageUrl));

          // Verify URL contains /render/image/public/ segment
          expect(url, contains('/render/image/public/'));

          // Verify URL contains bucket name
          expect(url, contains('/$bucket/'));

          // Verify URL has query parameters
          expect(url, contains('?'));

          // Verify default format parameter is present
          expect(url, contains('format=webp'));
        },
      );

      Glados2<int, int>(widthGen, heightGen).test(
        'For any width and height, transformed URL includes dimension parameters',
        (width, height) {
          const storageUrl = 'https://api.haokir.com/storage/v1';
          const bucket = 'anime-covers';
          const path = 'cover.jpg';

          final url = SupabaseStorage.buildTransformedUrl(
            storageUrl,
            bucket,
            path,
            width: width,
            height: height,
          );

          // Verify width parameter
          expect(url, contains('width=$width'));

          // Verify height parameter
          expect(url, contains('height=$height'));
        },
      );

      Glados<String>(formatGen).test(
        'For any format, transformed URL includes format parameter',
        (format) {
          const storageUrl = 'https://api.haokir.com/storage/v1';
          const bucket = 'anime-covers';
          const path = 'cover.jpg';

          final url = SupabaseStorage.buildTransformedUrl(
            storageUrl,
            bucket,
            path,
            format: format,
          );

          // Verify format parameter
          expect(url, contains('format=$format'));
        },
      );

      Glados<int>(qualityGen).test(
        'For any quality value 1-100, transformed URL includes quality parameter',
        (quality) {
          const storageUrl = 'https://api.haokir.com/storage/v1';
          const bucket = 'anime-covers';
          const path = 'cover.jpg';

          final url = SupabaseStorage.buildTransformedUrl(
            storageUrl,
            bucket,
            path,
            quality: quality,
          );

          // Verify quality parameter
          expect(url, contains('quality=$quality'));
        },
      );

      test('Transformed URL includes resize parameter when not default', () {
        const storageUrl = 'https://api.haokir.com/storage/v1';
        const bucket = 'anime-covers';
        const path = 'cover.jpg';

        // Default resize (cover) should not be in URL
        final urlDefault = SupabaseStorage.buildTransformedUrl(
          storageUrl,
          bucket,
          path,
          resize: 'cover',
        );
        expect(urlDefault, isNot(contains('resize=')));

        // Non-default resize should be in URL
        final urlContain = SupabaseStorage.buildTransformedUrl(
          storageUrl,
          bucket,
          path,
          resize: 'contain',
        );
        expect(urlContain, contains('resize=contain'));

        final urlFill = SupabaseStorage.buildTransformedUrl(
          storageUrl,
          bucket,
          path,
          resize: 'fill',
        );
        expect(urlFill, contains('resize=fill'));
      });
    });

    group('Path normalization', () {
      test('Empty path segments are handled correctly', () {
        const storageUrl = 'https://api.haokir.com/storage/v1';
        const bucket = 'anime-covers';

        // Path with only slashes should result in empty path
        final url = SupabaseStorage.buildPublicUrl(storageUrl, bucket, '///');
        expect(url, equals('$storageUrl/object/public/$bucket/'));
      });

      Glados<String>(pathGen).test(
        'For any path, the result URL is a valid URI',
        (path) {
          const storageUrl = 'https://api.haokir.com/storage/v1';
          const bucket = 'anime-covers';

          final url = SupabaseStorage.buildPublicUrl(storageUrl, bucket, path);

          // Should be parseable as a URI
          expect(() => Uri.parse(url), returnsNormally);

          final uri = Uri.parse(url);
          expect(uri.scheme, equals('https'));
          expect(uri.host, equals('api.haokir.com'));
        },
      );
    });
  });
}
