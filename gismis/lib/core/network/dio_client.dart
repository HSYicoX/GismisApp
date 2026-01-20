import 'dart:io';

import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'auth_interceptor.dart';

/// Configuration for the DioClient.
class DioClientConfig {
  const DioClientConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.maxRetries = 1,
    this.retryDelay = const Duration(seconds: 1),
  });

  /// Base URL for all API requests.
  final String baseUrl;

  /// Connection timeout duration.
  final Duration connectTimeout;

  /// Send timeout duration.
  final Duration sendTimeout;

  /// Receive timeout duration.
  final Duration receiveTimeout;

  /// Maximum number of retry attempts for failed requests.
  final int maxRetries;

  /// Delay between retry attempts.
  final Duration retryDelay;
}

/// HTTP client wrapper around Dio with authentication and retry support.
///
/// Features:
/// - Automatic token injection via AuthInterceptor
/// - Automatic 401 handling with token refresh
/// - Retry logic for failed requests
/// - Structured error handling via ApiException
class DioClient {
  DioClient({required DioClientConfig config})
    : _config = config,
      _dio = Dio(
        BaseOptions(
          baseUrl: config.baseUrl,
          connectTimeout: config.connectTimeout,
          sendTimeout: config.sendTimeout,
          receiveTimeout: config.receiveTimeout,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
  final Dio _dio;
  final DioClientConfig _config;
  AuthInterceptor? _authInterceptor;

  /// The underlying Dio instance (for advanced use cases).
  Dio get dio => _dio;

  /// Sets up authentication interceptor for token management.
  void setupAuth({
    required Future<String?> Function() getToken,
    required Future<bool> Function() refreshToken,
    void Function()? onAuthFailure,
  }) {
    // Remove existing auth interceptor if any
    if (_authInterceptor != null) {
      _dio.interceptors.remove(_authInterceptor);
    }

    _authInterceptor = AuthInterceptor(
      getToken: getToken,
      refreshToken: refreshToken,
      dio: _dio,
      onAuthFailure: onAuthFailure,
    );

    _dio.interceptors.add(_authInterceptor!);
  }

  /// Performs a GET request.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _executeWithRetry(
      () => _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  /// Performs a POST request.
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _executeWithRetry(
      () => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  /// Performs a PATCH request.
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _executeWithRetry(
      () => _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  /// Performs a PUT request.
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _executeWithRetry(
      () => _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  /// Performs a DELETE request.
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _executeWithRetry(
      () => _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  /// Executes a request with retry logic.
  Future<Response<T>> _executeWithRetry<T>(
    Future<Response<T>> Function() request,
  ) async {
    var attempts = 0;

    while (true) {
      try {
        return await request();
      } on DioException catch (e) {
        attempts++;
        final apiException = _mapDioException(e);

        // Only retry if the error is retryable and we haven't exceeded max retries
        if (apiException.isRetryable && attempts <= _config.maxRetries) {
          await Future<void>.delayed(_config.retryDelay * attempts);
          continue;
        }

        throw apiException;
      }
    }
  }

  /// Maps a DioException to an ApiException.
  ApiException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return ApiException.connectionTimeout();
      case DioExceptionType.sendTimeout:
        return ApiException.sendTimeout();
      case DioExceptionType.receiveTimeout:
        return ApiException.receiveTimeout();
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode != null) {
          return ApiException.fromStatusCode(
            statusCode,
            message: _extractErrorMessage(e.response),
            responseData: e.response?.data,
          );
        }
        return ApiException.unknown(originalError: e);
      case DioExceptionType.cancel:
        return ApiException.cancelled();
      case DioExceptionType.connectionError:
        return ApiException.noConnection();
      case DioExceptionType.badCertificate:
        return ApiException.unknown(
          message: 'SSL certificate error. Please check your connection.',
          originalError: e,
        );
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return ApiException.noConnection();
        }
        return ApiException.unknown(originalError: e);
    }
  }

  /// Extracts error message from response data.
  String? _extractErrorMessage(Response<dynamic>? response) {
    if (response?.data == null) return null;

    final data = response!.data;
    if (data is Map<String, dynamic>) {
      // Try common error message fields
      return data['message'] as String? ??
          data['error'] as String? ??
          data['error_description'] as String?;
    }

    if (data is String && data.isNotEmpty) {
      return data;
    }

    return null;
  }
}
