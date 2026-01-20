import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user.dart';
import '../../auth/domain/auth_providers.dart';
import '../../auth/domain/auth_service.dart';
import '../data/profile_repository.dart';

/// Provider for the ProfileRepository instance.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ProfileRepository(client: dioClient);
});

/// Provider for the current user's profile.
///
/// This provider fetches the profile from the API and caches it.
/// It automatically refreshes when the auth state changes.
final profileProvider = FutureProvider<User?>((ref) async {
  final authState = ref.watch(authStateProvider);

  // Only fetch profile if authenticated
  return authState.when(
    data: (state) async {
      if (state == AuthState.authenticated) {
        final repository = ref.watch(profileRepositoryProvider);
        return repository.getProfile();
      }
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Notifier for managing profile state with update actions.
class ProfileNotifier extends StateNotifier<AsyncValue<User?>> {
  ProfileNotifier(this._repository) : super(const AsyncValue.loading());
  final ProfileRepository _repository;

  /// Loads the current user's profile.
  Future<void> loadProfile() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.getProfile();
      state = AsyncValue.data(user);
    } on Exception catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Updates the user's profile.
  ///
  /// [username] - New username (optional)
  /// [avatarUrl] - New avatar URL (optional)
  Future<bool> updateProfile({String? username, String? avatarUrl}) async {
    try {
      final updatedUser = await _repository.updateProfile(
        username: username,
        avatarUrl: avatarUrl,
      );
      state = AsyncValue.data(updatedUser);
      return true;
    } on Exception catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Clears the profile state (e.g., on logout).
  void clear() {
    state = const AsyncValue.data(null);
  }
}

/// Provider for the ProfileNotifier.
final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<User?>>((ref) {
      final repository = ref.watch(profileRepositoryProvider);
      return ProfileNotifier(repository);
    });
