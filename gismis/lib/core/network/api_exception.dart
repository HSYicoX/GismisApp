/// API exception types for structured error handling.
///
/// This file defines the error types that can occur during API communication,
/// allowing the UI layer to handle errors appropriately.
library;

/// Enum representing different types of API errors.
enum ApiErrorType {
  /// Connection timeout - server didn't respond in time
  connectionTimeout,

  /// Send timeout - request took too long to send
  sendTimeout,

  /// Receive timeout - response took too long to receive
  receiveTimeout,

  /// Bad request (400) - invalid request parameters
  badRequest,

  /// Unauthorized (401) - authentication required or token expired
  unauthorized,

  /// Forbidden (403) - insufficient permissions
  forbidden,

  /// Not found (404) - resource doesn't exist
  notFound,

  /// Server error (5xx) - backend issue
  serverError,

  /// No internet connection
  noConnection,

  /// Request was cancelled
  cancelled,

  /// Unknown error
  unknown,
}

/// Exception class for API errors with structured information.
class ApiException implements Exception {
  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.originalError,
    this.responseData,
  });

  /// Creates an ApiException from an HTTP status code.
  factory ApiException.fromStatusCode(
    int statusCode, {
    String? message,
    dynamic responseData,
  }) {
    final type = _typeFromStatusCode(statusCode);
    return ApiException(
      type: type,
      message: message ?? _defaultMessageForType(type),
      statusCode: statusCode,
      responseData: responseData,
    );
  }

  /// Creates a connection timeout exception.
  factory ApiException.connectionTimeout({String? message}) {
    return ApiException(
      type: ApiErrorType.connectionTimeout,
      message:
          message ??
          'Connection timed out. Please check your internet connection.',
    );
  }

  /// Creates a send timeout exception.
  factory ApiException.sendTimeout({String? message}) {
    return ApiException(
      type: ApiErrorType.sendTimeout,
      message: message ?? 'Request timed out. Please try again.',
    );
  }

  /// Creates a receive timeout exception.
  factory ApiException.receiveTimeout({String? message}) {
    return ApiException(
      type: ApiErrorType.receiveTimeout,
      message: message ?? 'Server response timed out. Please try again.',
    );
  }

  /// Creates a no connection exception.
  factory ApiException.noConnection({String? message}) {
    return ApiException(
      type: ApiErrorType.noConnection,
      message: message ?? 'No internet connection. Please check your network.',
    );
  }

  /// Creates a cancelled request exception.
  factory ApiException.cancelled({String? message}) {
    return ApiException(
      type: ApiErrorType.cancelled,
      message: message ?? 'Request was cancelled.',
    );
  }

  /// Creates an unknown error exception.
  factory ApiException.unknown({String? message, dynamic originalError}) {
    return ApiException(
      type: ApiErrorType.unknown,
      message: message ?? 'An unexpected error occurred. Please try again.',
      originalError: originalError,
    );
  }

  /// The type of error that occurred.
  final ApiErrorType type;

  /// Human-readable error message.
  final String message;

  /// HTTP status code if available.
  final int? statusCode;

  /// Original error/exception if available.
  final dynamic originalError;

  /// Response data if available.
  final dynamic responseData;

  static ApiErrorType _typeFromStatusCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return ApiErrorType.badRequest;
      case 401:
        return ApiErrorType.unauthorized;
      case 403:
        return ApiErrorType.forbidden;
      case 404:
        return ApiErrorType.notFound;
      default:
        if (statusCode >= 500) {
          return ApiErrorType.serverError;
        }
        return ApiErrorType.unknown;
    }
  }

  static String _defaultMessageForType(ApiErrorType type) {
    switch (type) {
      case ApiErrorType.connectionTimeout:
        return 'Connection timed out. Please check your internet connection.';
      case ApiErrorType.sendTimeout:
        return 'Request timed out. Please try again.';
      case ApiErrorType.receiveTimeout:
        return 'Server response timed out. Please try again.';
      case ApiErrorType.badRequest:
        return 'Invalid request. Please check your input.';
      case ApiErrorType.unauthorized:
        return 'Authentication required. Please log in again.';
      case ApiErrorType.forbidden:
        return "You don't have permission to access this resource.";
      case ApiErrorType.notFound:
        return 'The requested content was not found.';
      case ApiErrorType.serverError:
        return 'Server error. Please try again later.';
      case ApiErrorType.noConnection:
        return 'No internet connection. Please check your network.';
      case ApiErrorType.cancelled:
        return 'Request was cancelled.';
      case ApiErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Whether this error is retryable.
  bool get isRetryable {
    switch (type) {
      case ApiErrorType.connectionTimeout:
      case ApiErrorType.sendTimeout:
      case ApiErrorType.receiveTimeout:
      case ApiErrorType.serverError:
      case ApiErrorType.noConnection:
        return true;
      case ApiErrorType.badRequest:
      case ApiErrorType.unauthorized:
      case ApiErrorType.forbidden:
      case ApiErrorType.notFound:
      case ApiErrorType.cancelled:
      case ApiErrorType.unknown:
        return false;
    }
  }

  @override
  String toString() =>
      'ApiException(type: $type, message: $message, statusCode: $statusCode)';
}
