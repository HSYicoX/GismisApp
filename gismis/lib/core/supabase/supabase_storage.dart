/// Supabase Storage service for file operations.
///
/// This service handles all Storage operations with proper permission handling:
/// - Public buckets (anime-covers, anime-banners): Direct URL access
/// - Private buckets (user-avatars): Upload via Edge Functions, access via signed URLs
///
/// Key constraints:
/// - Public bucket URLs can be generated client-side
/// - Private bucket uploads MUST go through Edge Functions (service_role required)
/// - Private bucket access requires signed URLs via Edge Functions
library;

import 'package:dio/dio.dart';

import '../network/api_exception.dart';
import 'supabase_config.dart';
import 'supabase_error.dart';

/// Supabase Storage service.
///
/// Provides methods for generating URLs and handling file operations
/// with proper permission boundaries.
///
/// Usage:
/// ```dart
/// final storage = SupabaseStorage(
///   config: SupabaseConfig.prod(),
///   dio: Dio(),
/// );
///
/// // Public bucket URL
/// final coverUrl = storage.getPublicUrl('anime-covers', 'cover.jpg');
///
/// // Transformed image URL
/// final thumbUrl = storage.getTransformedUrl(
///   'anime-covers',
///   'cover.jpg',
///   width: 200,
///   height: 300,
/// );
///
/// // Private upload via Edge Function
/// final avatarUrl = await storage.uploadViaFunction(
///   functionName: 'upload-avatar',
///   accessToken: token,
///   fileName: 'avatar.jpg',
///   bytes: imageBytes,
///   contentType: 'image/jpeg',
/// );
///
/// // Get signed URL for private file
/// final signedUrl = await storage.getSignedUrl(
///   functionName: 'get-signed-url',
///   accessToken: token,
///   bucket: 'user-avatars',
///   path: 'user123/avatar.jpg',
/// );
/// ```
class SupabaseStorage {
  /// Creates a new Storage service with the given configuration.
  SupabaseStorage({required SupabaseConfig config, Dio? dio})
    : _config = config,
      _dio = dio ?? Dio();

  final SupabaseConfig _config;
  final Dio _dio;

  /// Generates a public URL for a file in a public bucket.
  ///
  /// Use this for public buckets like `anime-covers` and `anime-banners`.
  /// The URL can be used directly without authentication.
  ///
  /// Parameters:
  /// - [bucket]: The bucket name (e.g., 'anime-covers')
  /// - [path]: The file path within the bucket (e.g., 'cover.jpg')
  ///
  /// Returns the full public URL for the file.
  ///
  /// Example:
  /// ```dart
  /// final url = storage.getPublicUrl('anime-covers', 'abc123/cover.jpg');
  /// // Returns: https://api.haokir.com/storage/v1/object/public/anime-covers/abc123/cover.jpg
  /// ```
  String getPublicUrl(String bucket, String path) {
    final cleanPath = _cleanPath(path);
    return '${_config.storageUrl}/object/public/$bucket/$cleanPath';
  }

  /// Generates a transformed image URL with resizing and format conversion.
  ///
  /// Uses Supabase's image transformation feature to resize and convert images
  /// on-the-fly. Note: This feature must be enabled on the self-hosted instance.
  ///
  /// Parameters:
  /// - [bucket]: The bucket name
  /// - [path]: The file path within the bucket
  /// - [width]: Target width in pixels (optional)
  /// - [height]: Target height in pixels (optional)
  /// - [format]: Output format (default: 'webp')
  /// - [quality]: Image quality 1-100 (optional, default varies by format)
  /// - [resize]: Resize mode: 'cover', 'contain', or 'fill' (default: 'cover')
  ///
  /// Returns the transformation URL.
  ///
  /// Example:
  /// ```dart
  /// final thumbUrl = storage.getTransformedUrl(
  ///   'anime-covers',
  ///   'cover.jpg',
  ///   width: 200,
  ///   height: 300,
  ///   format: 'webp',
  ///   quality: 80,
  /// );
  /// ```
  String getTransformedUrl(
    String bucket,
    String path, {
    int? width,
    int? height,
    String format = 'webp',
    int? quality,
    String resize = 'cover',
  }) {
    final cleanPath = _cleanPath(path);
    final params = <String>[];

    if (width != null) params.add('width=$width');
    if (height != null) params.add('height=$height');
    params.add('format=$format');
    if (quality != null) params.add('quality=$quality');
    if (resize != 'cover') params.add('resize=$resize');

    final queryString = params.join('&');
    return '${_config.storageUrl}/render/image/public/$bucket/$cleanPath?$queryString';
  }

  /// Uploads a file to a private bucket via an Edge Function.
  ///
  /// Private bucket uploads MUST go through Edge Functions because:
  /// - The client only has the anon key
  /// - Writing to private buckets requires service_role
  /// - The Edge Function validates the JWT and handles the upload
  ///
  /// Parameters:
  /// - [functionName]: The Edge Function name (e.g., 'upload-avatar')
  /// - [accessToken]: JWT access token for authentication
  /// - [fileName]: The file name
  /// - [bytes]: The file content as bytes
  /// - [contentType]: The MIME type (e.g., 'image/jpeg')
  /// - [onProgress]: Optional progress callback (sent, total)
  ///
  /// Returns the uploaded file URL/path from the Edge Function response.
  ///
  /// Throws [ApiException] on error.
  Future<UploadResult> uploadViaFunction({
    required String functionName,
    required String accessToken,
    required String fileName,
    required List<int> bytes,
    required String contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: DioMediaType.parse(contentType),
        ),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '${_config.functionsUrl}/$functionName',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'apikey': _config.anonKey,
          },
        ),
        onSendProgress: onProgress,
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException(
          type: ApiErrorType.serverError,
          message: 'Empty response from upload function',
        );
      }

      return UploadResult(
        url: data['avatar_url'] as String? ?? data['url'] as String? ?? '',
        path: data['path'] as String? ?? '',
      );
    } on DioException catch (e) {
      throw mapSupabaseError(e);
    }
  }

  /// Gets a signed URL for accessing a private file.
  ///
  /// Private files require signed URLs because:
  /// - The client only has the anon key
  /// - Private bucket access requires service_role to generate signed URLs
  /// - The Edge Function validates the JWT and generates the signed URL
  ///
  /// Parameters:
  /// - [functionName]: The Edge Function name (e.g., 'get-signed-url')
  /// - [accessToken]: JWT access token for authentication
  /// - [bucket]: The bucket name (e.g., 'user-avatars')
  /// - [path]: The file path within the bucket
  /// - [expiresIn]: URL expiration time in seconds (default: 3600)
  ///
  /// Returns a [SignedUrlResult] containing the signed URL and expiration.
  ///
  /// Throws [ApiException] on error.
  Future<SignedUrlResult> getSignedUrl({
    required String functionName,
    required String accessToken,
    required String bucket,
    required String path,
    int expiresIn = 3600,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${_config.functionsUrl}/$functionName',
        data: {'bucket': bucket, 'path': path, 'expiresIn': expiresIn},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'apikey': _config.anonKey,
            'Content-Type': 'application/json',
          },
        ),
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException(
          type: ApiErrorType.serverError,
          message: 'Empty response from signed URL function',
        );
      }

      return SignedUrlResult(
        signedUrl: data['signedUrl'] as String? ?? '',
        expiresAt: data['expiresAt'] != null
            ? DateTime.parse(data['expiresAt'] as String)
            : DateTime.now().add(Duration(seconds: expiresIn)),
      );
    } on DioException catch (e) {
      throw mapSupabaseError(e);
    }
  }

  /// Cleans a file path by removing leading slashes and normalizing.
  String _cleanPath(String path) {
    return path
        .replaceAll(RegExp(r'^/+'), '') // Remove leading slashes
        .replaceAll(RegExp(r'/+'), '/'); // Normalize multiple slashes
  }

  // Static utility methods for URL generation (useful for testing)

  /// Builds a public URL for a given storage URL, bucket, and path.
  ///
  /// This is a static utility method for testing and external use.
  static String buildPublicUrl(String storageUrl, String bucket, String path) {
    final cleanPath = path
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+'), '/');
    return '$storageUrl/object/public/$bucket/$cleanPath';
  }

  /// Builds a transformed image URL with the given parameters.
  ///
  /// This is a static utility method for testing and external use.
  static String buildTransformedUrl(
    String storageUrl,
    String bucket,
    String path, {
    int? width,
    int? height,
    String format = 'webp',
    int? quality,
    String resize = 'cover',
  }) {
    final cleanPath = path
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+'), '/');

    final params = <String>[];
    if (width != null) params.add('width=$width');
    if (height != null) params.add('height=$height');
    params.add('format=$format');
    if (quality != null) params.add('quality=$quality');
    if (resize != 'cover') params.add('resize=$resize');

    final queryString = params.join('&');
    return '$storageUrl/render/image/public/$bucket/$cleanPath?$queryString';
  }
}

/// Result of a file upload operation.
class UploadResult {
  /// Creates an upload result.
  const UploadResult({required this.url, required this.path});

  /// The URL or reference to the uploaded file.
  final String url;

  /// The path of the uploaded file within the bucket.
  final String path;

  @override
  String toString() => 'UploadResult(url: $url, path: $path)';
}

/// Result of a signed URL request.
class SignedUrlResult {
  /// Creates a signed URL result.
  const SignedUrlResult({required this.signedUrl, required this.expiresAt});

  /// The signed URL for accessing the private file.
  final String signedUrl;

  /// When the signed URL expires.
  final DateTime expiresAt;

  /// Whether the signed URL has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Time remaining until expiration.
  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  @override
  String toString() =>
      'SignedUrlResult(signedUrl: $signedUrl, expiresAt: $expiresAt)';
}
