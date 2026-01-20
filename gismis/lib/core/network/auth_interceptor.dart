import 'package:dio/dio.dart';

/// Callback type for getting the current access token.
typedef TokenGetter = Future<String?> Function();

/// Callback type for refreshing the access token.
/// Returns true if refresh was successful, false otherwise.
typedef TokenRefresher = Future<bool> Function();

/// Callback type for handling authentication failure (e.g., redirect to login).
typedef AuthFailureHandler = void Function();

/// Interceptor that handles JWT token injection and automatic refresh.
///
/// This interceptor:
/// 1. Adds Authorization header with Bearer token to all requests
/// 2. Handles 401 responses by attempting token refresh
/// 3. Retries the original request after successful refresh
/// 4. Calls failure handler if refresh fails
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenGetter getToken,
    required TokenRefresher refreshToken,
    required Dio dio,
    AuthFailureHandler? onAuthFailure,
  }) : _getToken = getToken,
       _refreshToken = refreshToken,
       _dio = dio,
       _onAuthFailure = onAuthFailure;
  final TokenGetter _getToken;
  final TokenRefresher _refreshToken;
  final AuthFailureHandler? _onAuthFailure;
  final Dio _dio;

  /// Whether a token refresh is currently in progress.
  bool _isRefreshing = false;

  /// Queue of requests waiting for token refresh to complete.
  final List<_RequestRetry> _pendingRequests = [];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header for auth endpoints
    if (_isAuthEndpoint(options.path)) {
      return handler.next(options);
    }

    final token = await _getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only handle 401 errors for non-auth endpoints
    if (err.response?.statusCode != 401 ||
        _isAuthEndpoint(err.requestOptions.path)) {
      return handler.next(err);
    }

    // If already refreshing, queue this request
    if (_isRefreshing) {
      return _queueRequest(err.requestOptions, handler);
    }

    _isRefreshing = true;

    try {
      final refreshSuccess = await _refreshToken();

      if (refreshSuccess) {
        // Retry the original request with new token
        final response = await _retryRequest(err.requestOptions);

        // Process queued requests
        _processQueue(success: true);

        return handler.resolve(response);
      } else {
        // Refresh failed, reject all pending requests
        _processQueue(success: false);
        _onAuthFailure?.call();
        return handler.next(err);
      }
    } catch (e) {
      _processQueue(success: false);
      _onAuthFailure?.call();
      return handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

  /// Checks if the path is an authentication endpoint (shouldn't add auth header).
  bool _isAuthEndpoint(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh');
  }

  /// Queues a request to be retried after token refresh.
  void _queueRequest(RequestOptions options, ErrorInterceptorHandler handler) {
    _pendingRequests.add(_RequestRetry(options: options, handler: handler));
  }

  /// Processes all queued requests after token refresh completes.
  void _processQueue({required bool success}) {
    for (final retry in _pendingRequests) {
      if (success) {
        _retryRequest(retry.options).then(
          retry.handler.resolve,
          onError: (Object e) => retry.handler.reject(e as DioException),
        );
      } else {
        retry.handler.reject(
          DioException(
            requestOptions: retry.options,
            error: 'Token refresh failed',
          ),
        );
      }
    }
    _pendingRequests.clear();
  }

  /// Retries a request with the new token.
  Future<Response<dynamic>> _retryRequest(RequestOptions options) async {
    final token = await _getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return _dio.fetch(options);
  }
}

/// Helper class to store pending request information.
class _RequestRetry {
  _RequestRetry({required this.options, required this.handler});
  final RequestOptions options;
  final ErrorInterceptorHandler handler;
}
