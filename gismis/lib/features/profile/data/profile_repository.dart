import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/user.dart';

/// Repository for user profile operations.
///
/// Handles communication with the backend profile endpoints:
/// - GET /me - Get current user profile
/// - PATCH /me - Update user profile
class ProfileRepository {
  ProfileRepository({required DioClient client}) : _client = client;
  final DioClient _client;

  /// Gets the current user's profile.
  ///
  /// Returns [User] on success, or null on failure.
  Future<User?> getProfile() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/me');

      if (response.data != null) {
        return User.fromJson(response.data!);
      }
      return null;
    } on ApiException {
      rethrow;
    }
  }

  /// Updates the current user's profile.
  ///
  /// [username] - New username (optional)
  /// [avatarUrl] - New avatar URL (optional)
  ///
  /// Returns updated [User] on success.
  Future<User> updateProfile({String? username, String? avatarUrl}) async {
    try {
      final data = <String, dynamic>{};
      if (username != null) data['username'] = username;
      if (avatarUrl != null) data['avatar_url'] = avatarUrl;

      final response = await _client.patch<Map<String, dynamic>>(
        '/me',
        data: data,
      );

      if (response.data != null) {
        return User.fromJson(response.data!);
      }

      throw ApiException.unknown(message: 'Failed to update profile');
    } on ApiException {
      rethrow;
    }
  }
}
