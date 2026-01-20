import 'package:dio/dio.dart';
import 'package:gismis/core/network/auth_interceptor.dart';
import 'package:glados/glados.dart';

/// Feature: anime-tracker-app, Property 17: API Authorization Header
/// Validates: Requirements 10.1
///
/// For any authenticated API request, the request headers SHALL include
/// "Authorization: Bearer {accessToken}" where accessToken is the current valid token.

void main() {
  group('Property 17: API Authorization Header', () {
    late Dio dio;
    late String? currentToken;
    late RequestOptions? capturedOptions;

    setUp(() {
      dio = Dio();
      currentToken = null;
      capturedOptions = null;

      // Clear any existing interceptors
      dio.interceptors.clear();
    });

    /// Helper to set up auth interceptor and capture the request
    void setupInterceptor() {
      final authInterceptor = AuthInterceptor(
        getToken: () async => currentToken,
        refreshToken: () async => false,
        dio: dio,
      );

      dio.interceptors.add(authInterceptor);

      // Add a capture interceptor after auth interceptor to capture the modified request
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            // Reject to prevent actual network call
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                error: 'Test capture - no actual request made',
              ),
            );
          },
        ),
      );
    }

    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any non-empty token, authenticated requests include Authorization header',
      (token) async {
        currentToken = token;
        setupInterceptor();

        try {
          await dio.get<void>('/api/test');
        } on DioException catch (e) {
          // Expected - we reject to prevent actual network call
          if (e.type != DioExceptionType.cancel) rethrow;
        }

        // Property: Authorization header must be "Bearer {token}"
        expect(capturedOptions, isNotNull);
        final authHeader = capturedOptions!.headers['Authorization'];
        expect(authHeader, equals('Bearer $token'));
      },
    );

    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any token, login endpoint does NOT include Authorization header',
      (token) async {
        currentToken = token;
        setupInterceptor();

        try {
          await dio.post<void>('/auth/login');
        } on DioException catch (e) {
          if (e.type != DioExceptionType.cancel) rethrow;
        }

        expect(capturedOptions, isNotNull);
        // Auth endpoints should NOT have the Authorization header
        expect(
          capturedOptions!.headers['Authorization'],
          isNull,
          reason:
              'Auth endpoint /auth/login should not have Authorization header',
        );
      },
    );

    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any token, register endpoint does NOT include Authorization header',
      (token) async {
        currentToken = token;
        setupInterceptor();

        try {
          await dio.post<void>('/auth/register');
        } on DioException catch (e) {
          if (e.type != DioExceptionType.cancel) rethrow;
        }

        expect(capturedOptions, isNotNull);
        expect(
          capturedOptions!.headers['Authorization'],
          isNull,
          reason:
              'Auth endpoint /auth/register should not have Authorization header',
        );
      },
    );

    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any token, refresh endpoint does NOT include Authorization header',
      (token) async {
        currentToken = token;
        setupInterceptor();

        try {
          await dio.post<void>('/auth/refresh');
        } on DioException catch (e) {
          if (e.type != DioExceptionType.cancel) rethrow;
        }

        expect(capturedOptions, isNotNull);
        expect(
          capturedOptions!.headers['Authorization'],
          isNull,
          reason:
              'Auth endpoint /auth/refresh should not have Authorization header',
        );
      },
    );

    test('When token is null, no Authorization header is added', () async {
      currentToken = null;
      setupInterceptor();

      try {
        await dio.get<void>('/api/test');
      } on DioException catch (e) {
        if (e.type != DioExceptionType.cancel) rethrow;
      }

      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.headers['Authorization'], isNull);
    });

    test(
      'When token is empty string, no Authorization header is added',
      () async {
        currentToken = '';
        setupInterceptor();

        try {
          await dio.get<void>('/api/test');
        } on DioException catch (e) {
          if (e.type != DioExceptionType.cancel) rethrow;
        }

        expect(capturedOptions, isNotNull);
        expect(capturedOptions!.headers['Authorization'], isNull);
      },
    );
  });
}
