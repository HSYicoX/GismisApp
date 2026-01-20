import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/auth_result.dart';
import '../../../shared/models/auth_tokens.dart';
import '../../../shared/models/user.dart';

/// Repository for authentication API operations.
///
/// Handles communication with the backend auth endpoints:
/// - POST /auth/register - Register new user
/// - POST /auth/login - Login and get tokens
/// - POST /auth/refresh - Refresh access token
/// - POST /auth/logout - Invalidate refresh token
class AuthRepository {
  AuthRepository({required DioClient client}) : _client = client;
  final DioClient _client;

  /// Register a new user with email, username, and password.
  ///
  /// Returns [AuthResult.success] with tokens and user on success,
  /// or [AuthResult.failure] with appropriate error on failure.
  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/register',
        data: {'email': email, 'username': username, 'password': password},
      );

      return _parseAuthResponse(response.data!);
    } on ApiException catch (e) {
      return _mapApiExceptionToAuthResult(e);
    }
  }

  /// Login with email and password.
  ///
  /// Returns [AuthResult.success] with tokens and user on success,
  /// or [AuthResult.failure] with appropriate error on failure.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      return _parseAuthResponse(response.data!);
    } on ApiException catch (e) {
      return _mapApiExceptionToAuthResult(e);
    }
  }

  /// Refresh the access token using a refresh token.
  ///
  /// Returns new [AuthTokens] on success, or null on failure.
  Future<AuthTokens?> refreshToken(String refreshToken) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data;
      if (data != null && data.containsKey('tokens')) {
        return AuthTokens.fromJson(data['tokens'] as Map<String, dynamic>);
      }

      // Some APIs return tokens directly
      if (data != null && data.containsKey('access_token')) {
        return AuthTokens.fromJson(data);
      }

      return null;
    } on ApiException {
      return null;
    }
  }

  /// Logout and invalidate the refresh token on the server.
  ///
  /// Returns true if logout was successful, false otherwise.
  Future<bool> logout(String refreshToken) async {
    try {
      await _client.post<void>(
        '/auth/logout',
        data: {'refresh_token': refreshToken},
      );
      return true;
    } on ApiException {
      // Even if server logout fails, we should still clear local tokens
      return false;
    }
  }

  /// Get the current user profile.
  ///
  /// Returns [User] on success, or null on failure.
  Future<User?> getCurrentUser() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/me');

      if (response.data != null) {
        return User.fromJson(response.data!);
      }
      return null;
    } on ApiException {
      return null;
    }
  }

  /// Parse auth response into AuthResult.
  AuthResult _parseAuthResponse(Map<String, dynamic> data) {
    // Check for error response
    if (data.containsKey('error')) {
      final errorCode = data['error'] as String;
      return AuthResult.failure(AuthError.fromString(errorCode));
    }

    // Parse success response
    try {
      final tokens = AuthTokens.fromJson(
        data['tokens'] as Map<String, dynamic>,
      );
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      return AuthResult.success(tokens, user);
    } catch (e) {
      return AuthResult.failure(AuthError.unknown);
    }
  }

  /// Map API exception to AuthResult.
  AuthResult _mapApiExceptionToAuthResult(ApiException e) {
    // Check response data for specific error codes
    if (e.responseData is Map<String, dynamic>) {
      final data = e.responseData as Map<String, dynamic>;
      if (data.containsKey('error')) {
        return AuthResult.failure(
          AuthError.fromString(data['error'] as String),
        );
      }
    }

    // Map by error type
    switch (e.type) {
      case ApiErrorType.unauthorized:
        return AuthResult.failure(AuthError.invalidCredentials);
      case ApiErrorType.noConnection:
      case ApiErrorType.connectionTimeout:
      case ApiErrorType.sendTimeout:
      case ApiErrorType.receiveTimeout:
        return AuthResult.failure(AuthError.networkError);
      default:
        return AuthResult.failure(AuthError.unknown);
    }
  }
}
