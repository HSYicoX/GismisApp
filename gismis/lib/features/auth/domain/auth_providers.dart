import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/user.dart';
import '../data/auth_repository.dart';
import 'auth_service.dart';

/// Provider for the DioClient configuration.
///
/// This should be overridden in the app with actual configuration.
final dioClientConfigProvider = Provider<DioClientConfig>((ref) {
  // Default configuration - should be overridden in main.dart
  return const DioClientConfig(baseUrl: 'https://api.example.com');
});

/// Provider for the DioClient instance.
final dioClientProvider = Provider<DioClient>((ref) {
  final config = ref.watch(dioClientConfigProvider);
  return DioClient(config: config);
});

/// Provider for the SecureStorageService instance.
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Provider for the AuthRepository instance.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AuthRepository(client: dioClient);
});

/// Provider for the AuthService instance.
///
/// This is the main entry point for authentication operations.
final authServiceProvider = Provider<AuthService>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final dioClient = ref.watch(dioClientProvider);

  return AuthService(
    repository: repository,
    secureStorage: secureStorage,
    dioClient: dioClient,
  );
});

/// Provider for the current authentication state.
///
/// Emits [AuthState] values as authentication state changes.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Provider for the current authenticated user.
///
/// Returns null if not authenticated.
final currentUserProvider = Provider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.currentUser;
});

/// Provider to check if user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.isAuthenticated;
});

/// Notifier for managing authentication state with actions.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authService) : super(AuthState.loading) {
    // Listen to auth state changes
    _authService.authStateChanges.listen((state) {
      this.state = state;
    });
  }
  final AuthService _authService;

  /// Initialize authentication state.
  Future<void> initialize() async {
    await _authService.initialize();
  }

  /// Login with email and password.
  Future<bool> login({required String email, required String password}) async {
    final result = await _authService.login(email: email, password: password);
    return result.isSuccess;
  }

  /// Register a new user.
  Future<bool> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final result = await _authService.register(
      email: email,
      username: username,
      password: password,
    );
    return result.isSuccess;
  }

  /// Logout the current user.
  Future<void> logout() async {
    await _authService.logout();
  }
}

/// Provider for the AuthNotifier.
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});
