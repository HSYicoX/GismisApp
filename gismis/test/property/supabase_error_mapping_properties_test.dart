import 'package:dio/dio.dart';
import 'package:glados/glados.dart';

import 'package:gismis/core/network/api_exception.dart';
import 'package:gismis/core/supabase/supabase_error.dart';

/// Feature: supabase-integration, Property 2: Supabase error code mapping
/// Validates: Requirements 2.5
///
/// For any Supabase/PostgREST error response, the error SHALL be mapped
/// to the appropriate ApiException type based on the error code.

void main() {
  group('Property 2: Supabase error code mapping', () {
    // Helper to create a DioException with Supabase error response
    DioException createSupabaseError({
      required String code,
      String? message,
      String? hint,
      int statusCode = 400,
    }) {
      return DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: statusCode,
          data: {
            'code': code,
            'message': message ?? 'Error message',
            'hint': hint,
          },
        ),
      );
    }

    test('PGRST116 (row not found) maps to notFound', () {
      final error = createSupabaseError(
        code: 'PGRST116',
        message: 'Row not found',
        statusCode: 404,
      );

      final result = mapSupabaseError(error);

      expect(result.type, equals(ApiErrorType.notFound));
      expect(result.statusCode, equals(404));
    });

    test('PGRST301 (invalid range) maps to badRequest', () {
      final error = createSupabaseError(
        code: 'PGRST301',
        message: 'Invalid range',
        statusCode: 400,
      );

      final result = mapSupabaseError(error);

      expect(result.type, equals(ApiErrorType.badRequest));
      expect(result.statusCode, equals(400));
    });

    test('23505 (unique violation) maps to badRequest with 409 status', () {
      final error = createSupabaseError(
        code: '23505',
        message: 'Duplicate key value',
        statusCode: 409,
      );

      final result = mapSupabaseError(error);

      expect(result.type, equals(ApiErrorType.badRequest));
      expect(result.statusCode, equals(409));
    });

    test('42501 (insufficient privilege) maps to forbidden', () {
      final error = createSupabaseError(
        code: '42501',
        message: 'Permission denied',
        statusCode: 403,
      );

      final result = mapSupabaseError(error);

      expect(result.type, equals(ApiErrorType.forbidden));
      expect(result.statusCode, equals(403));
    });

    test('42P01 (table not found) maps to notFound', () {
      final error = createSupabaseError(
        code: '42P01',
        message: 'Table does not exist',
        statusCode: 404,
      );

      final result = mapSupabaseError(error);

      expect(result.type, equals(ApiErrorType.notFound));
      expect(result.statusCode, equals(404));
    });

    test('23503 (foreign key violation) maps to badRequest', () {
      final error = createSupabaseError(
        code: '23503',
        message: 'Foreign key violation',
        statusCode: 400,
      );

      final result = mapSupabaseError(error);

      expect(result.type, equals(ApiErrorType.badRequest));
    });

    test('23502 (not null violation) maps to badRequest', () {
      final error = createSupabaseError(
        code: '23502',
        message: 'Not null violation',
        statusCode: 400,
      );

      final result = mapSupabaseError(error);

      expect(result.type, equals(ApiErrorType.badRequest));
    });

    test('23514 (check constraint violation) maps to badRequest', () {
      final error = createSupabaseError(
        code: '23514',
        message: 'Check constraint violation',
        statusCode: 400,
      );

      final result = mapSupabaseError(error);

      expect(result.type, equals(ApiErrorType.badRequest));
    });

    // Property test: For any known error code, mapping produces consistent type
    Glados<int>(any.intInRange(0, 5)).test(
      'For any known PostgREST error code, mapping produces expected ApiErrorType',
      (index) {
        final knownCodes = [
          ('PGRST116', ApiErrorType.notFound, 404),
          ('PGRST301', ApiErrorType.badRequest, 400),
          ('23505', ApiErrorType.badRequest, 409),
          ('42501', ApiErrorType.forbidden, 403),
          ('42P01', ApiErrorType.notFound, 404),
          ('23503', ApiErrorType.badRequest, 400),
        ];

        if (index >= knownCodes.length) return;

        final (code, expectedType, statusCode) = knownCodes[index];
        final error = createSupabaseError(code: code, statusCode: statusCode);

        final result = mapSupabaseError(error);

        expect(
          result.type,
          equals(expectedType),
          reason: 'Code $code should map to $expectedType',
        );
      },
    );

    // Property test: Error message is preserved in mapping
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any error message, the message is preserved in ApiException',
      (message) {
        final error = createSupabaseError(
          code: 'PGRST116',
          message: message,
          statusCode: 404,
        );

        final result = mapSupabaseError(error);

        expect(result.message, contains(message));
      },
    );

    group('DioException type mapping', () {
      test('connectionTimeout maps to connectionTimeout', () {
        final error = DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: '/test'),
        );

        final result = mapSupabaseError(error);

        expect(result.type, equals(ApiErrorType.connectionTimeout));
      });

      test('sendTimeout maps to sendTimeout', () {
        final error = DioException(
          type: DioExceptionType.sendTimeout,
          requestOptions: RequestOptions(path: '/test'),
        );

        final result = mapSupabaseError(error);

        expect(result.type, equals(ApiErrorType.sendTimeout));
      });

      test('receiveTimeout maps to receiveTimeout', () {
        final error = DioException(
          type: DioExceptionType.receiveTimeout,
          requestOptions: RequestOptions(path: '/test'),
        );

        final result = mapSupabaseError(error);

        expect(result.type, equals(ApiErrorType.receiveTimeout));
      });

      test('cancel maps to cancelled', () {
        final error = DioException(
          type: DioExceptionType.cancel,
          requestOptions: RequestOptions(path: '/test'),
        );

        final result = mapSupabaseError(error);

        expect(result.type, equals(ApiErrorType.cancelled));
      });

      test('connectionError maps to noConnection', () {
        final error = DioException(
          type: DioExceptionType.connectionError,
          requestOptions: RequestOptions(path: '/test'),
        );

        final result = mapSupabaseError(error);

        expect(result.type, equals(ApiErrorType.noConnection));
      });
    });

    group('HTTP status code fallback', () {
      test('Unknown code with 401 status maps to unauthorized', () {
        final error = DioException(
          type: DioExceptionType.badResponse,
          requestOptions: RequestOptions(path: '/test'),
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 401,
            data: {'code': 'UNKNOWN', 'message': 'Unauthorized'},
          ),
        );

        final result = mapSupabaseError(error);

        expect(result.type, equals(ApiErrorType.unauthorized));
        expect(result.statusCode, equals(401));
      });

      test('Unknown code with 500 status maps to serverError', () {
        final error = DioException(
          type: DioExceptionType.badResponse,
          requestOptions: RequestOptions(path: '/test'),
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 500,
            data: {'code': 'UNKNOWN', 'message': 'Server error'},
          ),
        );

        final result = mapSupabaseError(error);

        expect(result.type, equals(ApiErrorType.serverError));
        expect(result.statusCode, equals(500));
      });
    });
  });
}
