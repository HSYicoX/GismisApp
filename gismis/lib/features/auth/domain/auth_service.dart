import 'dart:async';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/auth_result.dart';
import '../../../shared/models/auth_tokens.dart';
import '../../../shared/models/user.dart';
import '../data/auth_repository.dart';

/// Authentication state enum.
enum AuthState {
  /// User is authenticated with valid tokens.
  authenticated,

  /// User is not authenticated (no tokens or invalid tokens).
  unauthenticated,

  /// Authentication state is being determined.
  loading,
}

/// Service for managing authentication state and operations.
///
/// This service:
/// - Manages user authentication state
/// - Handles token storage and refresh
/// - Provides auth state stream for reactive UI updates
/// - Configures DioClient with auth interceptor
class AuthService {
  AuthService({
    required AuthRepository repository,
    required SecureStorageService secureStorage,
    required DioClient dioClient,
  }) : _repository = repository,
       _secureStorage = secureStorage,
       _dioClient = dioClient {
    // Setup auth interceptor on DioClient
    _dioClient.setupAuth(
      getToken: _getAccessToken,
      refreshToken: _refreshToken,
      onAuthFailure: _handleAuthFailure,
    );
  }
  final AuthRepository _repository;
  final SecureStorageService _secureStorage;
  final DioClient _dioClient;

  /// Stream controller for auth state changes.
  final _authStateController = StreamController<AuthState>.broadcast();

  /// Current authentication state.
  AuthState _currentState = AuthState.loading;

  /// Current authenticated user (null if not authenticated).
  User? _currentUser;

  /// Current auth tokens (null if not authenticated).
  AuthTokens? _currentTokens;

  /// Stream of authentication state changes.
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  /// Current authentication state.
  AuthState get currentState => _currentState;

  /// Current authenticated user.
  User? get currentUser => _currentUser;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => _currentState == AuthState.authenticated;

  /// Initialize the auth service by checking stored tokens.
  ///
  /// Call this on app startup to restore authentication state.
  Future<void> initialize() async {
    _updateState(AuthState.loading);

    final tokens = await _secureStorage.getTokens();
    if (tokens == null) {
      _updateState(AuthState.unauthenticated);
      return;
    }

    _currentTokens = tokens;

    // Check if tokens are expired
    if (tokens.isExpired) {
      // Try to refresh
      final refreshed = await _refreshToken();
      if (!refreshed) {
        await _clearAuthData();
        _updateState(AuthState.unauthenticated);
        return;
      }
    }

    // Fetch current user
    final user = await _repository.getCurrentUser();
    if (user != null) {
      _currentUser = user;
      _updateState(AuthState.authenticated);
    } else {
      // Token might be invalid, try refresh
      final refreshed = await _refreshToken();
      if (refreshed) {
        final retryUser = await _repository.getCurrentUser();
        if (retryUser != null) {
          _currentUser = retryUser;
          _updateState(AuthState.authenticated);
          return;
        }
      }
      await _clearAuthData();
      _updateState(AuthState.unauthenticated);
    }
  }

  /// Register a new user.
  ///
  /// Returns [AuthResult] indicating success or failure.
  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final result = await _repository.register(
      email: email,
      username: username,
      password: password,
    );

    if (result.isSuccess) {
      await _handleAuthSuccess(result);
    }

    return result;
  }

  /// Login with email and password.
  ///
  /// Returns [AuthResult] indicating success or failure.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final result = await _repository.login(email: email, password: password);

    if (result.isSuccess) {
      await _handleAuthSuccess(result);
    }

    return result;
  }

  /// Logout the current user.
  ///
  /// Clears local tokens and invalidates refresh token on server.
  Future<void> logout() async {
    final refreshToken = _currentTokens?.refreshToken;

    // Clear local data first
    await _clearAuthData();
    _updateState(AuthState.unauthenticated);

    // Then invalidate on server (best effort)
    if (refreshToken != null) {
      await _repository.logout(refreshToken);
    }
  }

  /// Manually refresh the access token.
  ///
  /// Returns true if refresh was successful.
  Future<bool> refreshToken() async {
    return _refreshToken();
  }

  /// Dispose of resources.
  void dispose() {
    _authStateController.close();
  }

  // ============================================================
  // Private Methods
  // ============================================================

  /// Get the current access token for API requests.
  Future<String?> _getAccessToken() async {
    return _currentTokens?.accessToken;
  }

  /// Refresh the access token.
  Future<bool> _refreshToken() async {
    final currentRefreshToken = _currentTokens?.refreshToken;
    if (currentRefreshToken == null) {
      return false;
    }

    final newTokens = await _repository.refreshToken(currentRefreshToken);
    if (newTokens == null) {
      return false;
    }

    _currentTokens = newTokens;
    await _secureStorage.saveTokens(newTokens);
    return true;
  }

  /// Handle authentication failure (called by auth interceptor).
  void _handleAuthFailure() {
    _clearAuthData();
    _updateState(AuthState.unauthenticated);
  }

  /// Handle successful authentication.
  Future<void> _handleAuthSuccess(AuthResult result) async {
    final tokens = result.tokensOrNull;
    final user = result.userOrNull;

    if (tokens != null && user != null) {
      _currentTokens = tokens;
      _currentUser = user;
      await _secureStorage.saveTokens(tokens);
      _updateState(AuthState.authenticated);
    }
  }

  /// Clear all authentication data.
  Future<void> _clearAuthData() async {
    _currentTokens = null;
    _currentUser = null;
    await _secureStorage.clearTokens();
  }

  /// Update authentication state and notify listeners.
  void _updateState(AuthState newState) {
    _currentState = newState;
    _authStateController.add(newState);
  }
}
