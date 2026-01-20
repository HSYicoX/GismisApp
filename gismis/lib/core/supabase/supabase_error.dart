/// Supabase error handling and mapping to ApiException.
///
/// This file provides utilities for converting Supabase/PostgREST error
/// responses into structured [ApiException] instances for consistent
/// error handling throughout the application.
library;

import 'package:dio/dio.dart';

import '../network/api_exception.dart';

/// Maps a Dio exception from Supabase to an [ApiException].
///
/// Handles PostgREST-specific error codes and maps them to appropriate
/// [ApiErrorType] values for consistent error handling.
///
/// PostgREST error codes handled:
/// - `PGRST116`: Row not found (404)
/// - `PGRST301`: Invalid range header (400)
/// - `23505`: Unique constraint violation (409 Conflict)
/// - `42501`: Insufficient privilege (403)
/// - `42P01`: Table not found (404)
ApiException mapSupabaseError(DioException e) {
  final data = e.response?.data;

  if (data is Map<String, dynamic>) {
    final code = data['code'] as String?;
    final message = data['message'] as String?;
    final hint = data['hint'] as String?;
    final details = data['details'] as String?;

    // Build a descriptive error message
    final errorMessage = _buildErrorMessage(message, hint, details);

    // Map PostgREST error codes to ApiException types
    final mappedError = _mapPostgrestCode(code, errorMessage, e);
    if (mappedError != null) {
      return mappedError;
    }

    // Fall back to HTTP status code mapping
    final statusCode = e.response?.statusCode;
    if (statusCode != null) {
      return ApiException.fromStatusCode(
        statusCode,
        message: errorMessage,
        responseData: data,
      );
    }
  }

  // Handle non-JSON error responses
  return _mapDioExceptionType(e);
}

/// Maps a PostgREST error code to an [ApiException].
///
/// Returns null if the code is not a recognized PostgREST error code,
/// allowing fallback to HTTP status code mapping.
ApiException? _mapPostgrestCode(
  String? code,
  String? message,
  DioException originalError,
) {
  if (code == null) return null;

  return switch (code) {
    // Row not found - typically from .single() queries
    'PGRST116' => ApiException(
      type: ApiErrorType.notFound,
      message: message ?? 'The requested resource was not found.',
      statusCode: 404,
      originalError: originalError,
    ),

    // Invalid range header - pagination error
    'PGRST301' => ApiException(
      type: ApiErrorType.badRequest,
      message: message ?? 'Invalid pagination range specified.',
      statusCode: 400,
      originalError: originalError,
    ),

    // Unique constraint violation - duplicate entry
    // Note: Using badRequest as ApiErrorType doesn't have conflict
    '23505' => ApiException(
      type: ApiErrorType.badRequest,
      message: message ?? 'A record with this identifier already exists.',
      statusCode: 409,
      originalError: originalError,
    ),

    // Insufficient privilege - RLS policy denied access
    '42501' => ApiException(
      type: ApiErrorType.forbidden,
      message: message ?? 'You do not have permission to perform this action.',
      statusCode: 403,
      originalError: originalError,
    ),

    // Table not found - schema error
    '42P01' => ApiException(
      type: ApiErrorType.notFound,
      message: message ?? 'The requested table does not exist.',
      statusCode: 404,
      originalError: originalError,
    ),

    // Foreign key violation
    '23503' => ApiException(
      type: ApiErrorType.badRequest,
      message: message ?? 'Referenced record does not exist.',
      statusCode: 400,
      originalError: originalError,
    ),

    // Not null violation
    '23502' => ApiException(
      type: ApiErrorType.badRequest,
      message: message ?? 'Required field is missing.',
      statusCode: 400,
      originalError: originalError,
    ),

    // Check constraint violation
    '23514' => ApiException(
      type: ApiErrorType.badRequest,
      message: message ?? 'Data validation failed.',
      statusCode: 400,
      originalError: originalError,
    ),

    // JWT errors from Edge Functions
    'PGRST301' || 'invalid_jwt' || 'jwt_expired' => ApiException(
      type: ApiErrorType.unauthorized,
      message: message ?? 'Authentication token is invalid or expired.',
      statusCode: 401,
      originalError: originalError,
    ),

    // Unrecognized code - return null for fallback handling
    _ => null,
  };
}

/// Builds a descriptive error message from PostgREST error components.
String? _buildErrorMessage(String? message, String? hint, String? details) {
  final parts = <String>[];

  if (message != null && message.isNotEmpty) {
    parts.add(message);
  }

  if (hint != null && hint.isNotEmpty && hint != message) {
    parts.add(hint);
  }

  if (details != null && details.isNotEmpty && details != message) {
    parts.add(details);
  }

  return parts.isEmpty ? null : parts.join('. ');
}

/// Maps Dio exception types to [ApiException].
ApiException _mapDioExceptionType(DioException e) {
  return switch (e.type) {
    DioExceptionType.connectionTimeout => ApiException.connectionTimeout(),
    DioExceptionType.sendTimeout => ApiException.sendTimeout(),
    DioExceptionType.receiveTimeout => ApiException.receiveTimeout(),
    DioExceptionType.cancel => ApiException.cancelled(),
    DioExceptionType.connectionError => ApiException.noConnection(),
    DioExceptionType.badResponse => _mapBadResponse(e),
    _ => ApiException.unknown(originalError: e),
  };
}

/// Maps a bad response to [ApiException] based on status code.
ApiException _mapBadResponse(DioException e) {
  final statusCode = e.response?.statusCode;
  if (statusCode != null) {
    return ApiException.fromStatusCode(
      statusCode,
      message: _extractErrorMessage(e.response),
      responseData: e.response?.data,
    );
  }
  return ApiException.unknown(originalError: e);
}

/// Extracts error message from response data.
String? _extractErrorMessage(Response<dynamic>? response) {
  if (response?.data == null) return null;

  final data = response!.data;
  if (data is Map<String, dynamic>) {
    return data['message'] as String? ??
        data['error'] as String? ??
        data['error_description'] as String?;
  }

  if (data is String && data.isNotEmpty) {
    return data;
  }

  return null;
}

/// Extension on [ApiErrorType] to add conflict type.
///
/// Note: This extends the existing ApiErrorType enum conceptually.
/// The actual conflict handling uses [ApiErrorType.badRequest] with
/// a specific message since we can't extend enums.
extension ApiExceptionSupabase on ApiException {
  /// Creates a conflict exception (HTTP 409).
  ///
  /// Used for unique constraint violations and other conflict scenarios.
  static ApiException conflict({String? message}) {
    return ApiException(
      type: ApiErrorType.badRequest, // Using badRequest as closest match
      message: message ?? 'A conflict occurred with the current state.',
      statusCode: 409,
    );
  }

  /// Whether this exception represents a conflict (HTTP 409).
  bool get isConflict => statusCode == 409;

  /// Whether this exception is a Supabase-specific error.
  bool get isSupabaseError =>
      responseData is Map<String, dynamic> &&
      (responseData as Map<String, dynamic>).containsKey('code');
}

/// Adds conflict type to ApiException for Supabase compatibility.
extension ApiExceptionConflict on ApiException {
  /// Creates a conflict exception.
  static ApiException conflict({String? message, dynamic responseData}) {
    return ApiException(
      type: ApiErrorType.badRequest,
      message: message ?? 'A conflict occurred.',
      statusCode: 409,
      responseData: responseData,
    );
  }
}
