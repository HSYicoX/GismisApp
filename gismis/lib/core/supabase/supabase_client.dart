/// Supabase dedicated HTTP client for PostgREST and Edge Functions.
///
/// This client is separate from the global DioClient to avoid polluting
/// the global configuration with Supabase-specific headers and interceptors.
///
/// Key features:
/// - Independent Dio instance with Supabase-specific configuration
/// - PostgREST query support with Range/Content-Range pagination
/// - Edge Function invocation with JWT authentication
/// - Proper error mapping to ApiException
library;

import 'package:dio/dio.dart';

import '../network/api_exception.dart';
import 'paginated_result.dart';
import 'supabase_config.dart';
import 'supabase_error.dart';

/// Supabase dedicated HTTP client.
///
/// Creates an independent Dio instance configured specifically for Supabase
/// services, without affecting the global DioClient configuration.
///
/// Usage:
/// ```dart
/// final client = SupabaseClient(config: SupabaseConfig.prod());
///
/// // Query PostgREST
/// final result = await client.query<Anime>(
///   table: 'anime',
///   fromJson: Anime.fromJson,
///   limit: 20,
///   offset: 0,
/// );
///
/// // Call Edge Function
/// final response = await client.callFunction(
///   'get-favorites',
///   accessToken: token,
/// );
/// ```
class SupabaseClient {
  /// Creates a new Supabase client with the given configuration.
  SupabaseClient({required SupabaseConfig config}) : _config = config {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'apikey': config.anonKey,
        },
      ),
    );
  }

  late final Dio _dio;
  final SupabaseConfig _config;

  /// The underlying Dio instance for advanced use cases.
  ///
  /// Use with caution - prefer the typed methods like [query] and [callFunction].
  Dio get dio => _dio;

  /// The Supabase configuration.
  SupabaseConfig get config => _config;

  /// Performs a PostgREST query with pagination support.
  ///
  /// Implements the Range/Content-Range pagination contract:
  /// - Sends `Range: items=start-end` header for pagination
  /// - Parses `Content-Range: items start-end/total` response header
  ///
  /// Parameters:
  /// - [table]: The table name to query
  /// - [fromJson]: Factory function to deserialize JSON to type T
  /// - [select]: PostgREST select clause (default: '*')
  /// - [filters]: Map of filter conditions (e.g., {'status': 'eq.active'})
  /// - [order]: Order clause (e.g., 'created_at.desc')
  /// - [limit]: Maximum number of items to return
  /// - [offset]: Number of items to skip
  /// - [countTotal]: Whether to request total count (default: true)
  ///
  /// Returns a [PaginatedResult] containing the items and pagination metadata.
  ///
  /// Throws [ApiException] on error.
  Future<PaginatedResult<T>> query<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromJson,
    String select = '*',
    Map<String, String>? filters,
    String? order,
    int? limit,
    int? offset,
    bool countTotal = true,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'select': select,
        ...?filters,
        if (order != null) 'order': order,
      };

      final headers = <String, String>{'Range-Unit': 'items'};

      // Build Range header for pagination
      if (limit != null) {
        final start = offset ?? 0;
        final end = start + limit - 1;
        headers['Range'] = '$start-$end';
      }

      // Request exact count if needed
      if (countTotal) {
        headers['Prefer'] = 'count=exact';
      }

      final response = await _dio.get<List<dynamic>>(
        '${_config.restUrl}/$table',
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      final items = (response.data ?? [])
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();

      // Parse total count from Content-Range header
      // Format: "items start-end/total" or "items */total"
      final contentRange = response.headers.value('content-range');
      int? total;
      if (contentRange != null) {
        final match = RegExp(r'/(\d+)$').firstMatch(contentRange);
        if (match != null) {
          total = int.tryParse(match.group(1)!);
        }
      }

      final actualOffset = offset ?? 0;
      final hasMore = total != null
          ? actualOffset + items.length < total
          : items.isNotEmpty;

      return PaginatedResult<T>(
        items: items,
        total: total,
        offset: actualOffset,
        limit: limit,
        hasMore: hasMore,
      );
    } on DioException catch (e) {
      throw mapSupabaseError(e);
    }
  }

  /// Performs a single-item query.
  ///
  /// Convenience method for fetching a single item by ID or unique constraint.
  /// Uses PostgREST's `.single()` behavior via `Prefer: return=representation`.
  ///
  /// Throws [ApiException] with type [ApiErrorType.notFound] if no item found.
  Future<T> querySingle<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromJson,
    String select = '*',
    required Map<String, String> filters,
  }) async {
    try {
      final queryParams = <String, dynamic>{'select': select, ...filters};

      final response = await _dio.get<List<dynamic>>(
        '${_config.restUrl}/$table',
        queryParameters: queryParams,
        options: Options(
          headers: {'Accept': 'application/vnd.pgrst.object+json'},
        ),
      );

      if (response.data == null || response.data!.isEmpty) {
        throw ApiException(
          type: ApiErrorType.notFound,
          message: 'No item found matching the criteria.',
          statusCode: 404,
        );
      }

      return fromJson(response.data!.first as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapSupabaseError(e);
    }
  }

  /// Calls an Edge Function.
  ///
  /// Edge Functions are used for all private operations that require
  /// server-side JWT validation and service_role access.
  ///
  /// Parameters:
  /// - [functionName]: The name of the Edge Function to call
  /// - [accessToken]: JWT access token for authentication
  /// - [data]: Request body data (optional)
  /// - [headers]: Additional headers (optional)
  /// - [queryParameters]: URL query parameters (optional)
  ///
  /// Returns the Dio [Response] for flexible handling.
  ///
  /// Throws [ApiException] on error.
  Future<Response<T>> callFunction<T>(
    String functionName, {
    required String accessToken,
    dynamic data,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.post<T>(
        '${_config.functionsUrl}/$functionName',
        data: data,
        queryParameters: queryParameters,
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken', ...?headers},
        ),
      );
    } on DioException catch (e) {
      throw mapSupabaseError(e);
    }
  }

  /// Calls an Edge Function with GET method.
  ///
  /// Some Edge Functions may use GET for read operations.
  Future<Response<T>> callFunctionGet<T>(
    String functionName, {
    required String accessToken,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get<T>(
        '${_config.functionsUrl}/$functionName',
        queryParameters: queryParameters,
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken', ...?headers},
        ),
      );
    } on DioException catch (e) {
      throw mapSupabaseError(e);
    }
  }

  /// Calls a public Edge Function with GET method (no authentication required).
  ///
  /// Used for public endpoints like get-anime-list, search-anime, get-schedule.
  /// These functions don't require JWT authentication.
  ///
  /// Parameters:
  /// - [functionName]: The name of the Edge Function to call
  /// - [headers]: Additional headers (optional)
  /// - [queryParameters]: URL query parameters (optional)
  ///
  /// Returns the Dio [Response] for flexible handling.
  ///
  /// Throws [ApiException] on error.
  Future<Response<T>> callPublicFunctionGet<T>(
    String functionName, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get<T>(
        '${_config.functionsUrl}/$functionName',
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      throw mapSupabaseError(e);
    }
  }

  /// Builds a Range header value for pagination.
  ///
  /// This is a utility method exposed for testing purposes.
  /// Format: "start-end" (e.g., "0-19" for first 20 items)
  static String buildRangeHeader({required int offset, required int limit}) {
    final start = offset;
    final end = offset + limit - 1;
    return '$start-$end';
  }

  /// Parses the total count from a Content-Range header.
  ///
  /// This is a utility method exposed for testing purposes.
  /// Format: "items start-end/total" or "items */total"
  ///
  /// Returns null if the header is missing or malformed.
  static int? parseContentRangeTotal(String? contentRange) {
    if (contentRange == null) return null;
    final match = RegExp(r'/(\d+)$').firstMatch(contentRange);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }
}
