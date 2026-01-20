/// Supabase Profile Repository for user profile operations.
///
/// Implements local caching with background refresh strategy:
/// - Reads return cached data immediately, then refresh in background
/// - Writes update server first, then update local cache
/// - Avatar uploads go through Edge Functions for private bucket access
///
/// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/supabase_storage.dart';
import 'models/user_profile.dart';

/// Repository for managing user profile with local cache + background refresh.
///
/// Access pattern:
/// - Read: Local cache first, background refresh from server
/// - Write: Server first via Edge Functions, then update local cache
/// - Avatar: Upload via Edge Function, access via signed URLs
///
/// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5
class SupabaseProfileRepository {
  /// Creates a new profile repository.
  SupabaseProfileRepository({
    required SupabaseClient supabaseClient,
    required SupabaseStorage supabaseStorage,
    required SecureStorageService tokenStorage,
    String boxName = 'supabase_profile',
  }) : _supabaseClient = supabaseClient,
       _supabaseStorage = supabaseStorage,
       _tokenStorage = tokenStorage,
       _boxName = boxName;

  final SupabaseClient _supabaseClient;
  final SupabaseStorage _supabaseStorage;
  final SecureStorageService _tokenStorage;
  final String _boxName;

  Box<String>? _box;
  bool _isInitialized = false;

  static const _profileKey = 'user_profile';
  static const _lastFetchKey = 'last_fetch_time';
  static const _cacheDuration = Duration(minutes: 30);

  /// Initialize the repository storage.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _box = await Hive.openBox<String>(_boxName);
    _isInitialized = true;
  }

  void _ensureInitialized() {
    if (!_isInitialized || _box == null) {
      throw StateError(
        'SupabaseProfileRepository not initialized. Call initialize() first.',
      );
    }
  }

  // ============================================================
  // Read Operations (Cache First + Background Refresh)
  // ============================================================

  /// Gets the user profile with cache-first strategy.
  ///
  /// Returns cached profile immediately if available, then triggers
  /// a background refresh from the server. If no cache exists,
  /// fetches from server directly.
  ///
  /// Requirements: 6.1, 6.5 - Cache with background refresh
  Future<UserProfile?> getProfile({bool forceRefresh = false}) async {
    _ensureInitialized();

    // Check if we have a cached profile
    final cached = _getCachedProfile();

    if (cached != null && !forceRefresh) {
      // Return cached data immediately
      // Trigger background refresh if cache is stale
      if (_isCacheStale()) {
        _refreshProfileInBackground();
      }
      return cached;
    }

    // No cache or force refresh - fetch from server
    return _fetchProfileFromServer();
  }

  /// Gets the cached profile without triggering refresh.
  UserProfile? _getCachedProfile() {
    _ensureInitialized();
    final jsonString = _box!.get(_profileKey);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserProfile.fromJson(json);
    } on FormatException {
      debugPrint('SupabaseProfileRepository: Malformed cached profile');
      return null;
    }
  }

  /// Checks if the cache is stale.
  bool _isCacheStale() {
    final lastFetchStr = _box!.get(_lastFetchKey);
    if (lastFetchStr == null) return true;

    try {
      final lastFetch = DateTime.parse(lastFetchStr);
      return DateTime.now().difference(lastFetch) > _cacheDuration;
    } on FormatException {
      return true;
    }
  }

  /// Refreshes profile in background (fire and forget).
  void _refreshProfileInBackground() {
    Future.microtask(() async {
      try {
        await _fetchProfileFromServer();
      } on Exception catch (e) {
        debugPrint('SupabaseProfileRepository: Background refresh failed: $e');
      }
    });
  }

  /// Fetches profile from server via Edge Function.
  ///
  /// Requirements: 6.1 - Get profile via Edge Function
  Future<UserProfile?> _fetchProfileFromServer() async {
    final token = await _tokenStorage.getAccessToken();
    if (token == null) {
      debugPrint('SupabaseProfileRepository: No token, cannot fetch profile');
      return null;
    }

    try {
      final response = await _supabaseClient
          .callFunctionGet<Map<String, dynamic>>(
            'get-profile',
            accessToken: token,
          );

      if (response.data == null) {
        return null;
      }

      final profile = UserProfile.fromJson(response.data!);

      // Update cache
      await _cacheProfile(profile);

      return profile;
    } on ApiException catch (e) {
      debugPrint('SupabaseProfileRepository: Fetch failed: ${e.message}');
      rethrow;
    }
  }

  /// Caches the profile locally.
  Future<void> _cacheProfile(UserProfile profile) async {
    _ensureInitialized();
    final jsonString = jsonEncode(profile.toJson());
    await _box!.put(_profileKey, jsonString);
    await _box!.put(_lastFetchKey, DateTime.now().toIso8601String());
  }

  // ============================================================
  // Write Operations (Server First + Cache Update)
  // ============================================================

  /// Updates the user profile.
  ///
  /// Sends update to server via Edge Function, then updates local cache.
  /// The Edge Function handles validation and sanitization.
  ///
  /// Requirements: 6.2 - Update profile via Edge Function
  Future<UserProfile> updateProfile(UpdateProfileRequest request) async {
    _ensureInitialized();

    if (!request.hasUpdates) {
      throw const ApiException(
        type: ApiErrorType.badRequest,
        message: 'No updates provided',
      );
    }

    final token = await _tokenStorage.getAccessToken();
    if (token == null) {
      throw const ApiException(
        type: ApiErrorType.unauthorized,
        message: 'Not authenticated',
      );
    }

    try {
      final response = await _supabaseClient.callFunction<Map<String, dynamic>>(
        'update-profile',
        accessToken: token,
        data: request.toJson(),
      );

      if (response.data == null) {
        throw const ApiException(
          type: ApiErrorType.serverError,
          message: 'Empty response from server',
        );
      }

      final profile = UserProfile.fromJson(response.data!);

      // Update cache with new profile
      await _cacheProfile(profile);

      return profile;
    } on ApiException {
      rethrow;
    }
  }

  /// Updates the user's nickname.
  ///
  /// Convenience method for updating just the nickname.
  Future<UserProfile> updateNickname(String nickname) async {
    return updateProfile(UpdateProfileRequest(nickname: nickname));
  }

  /// Updates the user's bio.
  ///
  /// Convenience method for updating just the bio.
  Future<UserProfile> updateBio(String bio) async {
    return updateProfile(UpdateProfileRequest(bio: bio));
  }

  /// Updates user preferences.
  ///
  /// Preferences are merged with existing preferences on the server.
  Future<UserProfile> updatePreferences(
    Map<String, dynamic> preferences,
  ) async {
    return updateProfile(UpdateProfileRequest(preferences: preferences));
  }

  // ============================================================
  // Avatar Operations
  // ============================================================

  /// Uploads a new avatar image.
  ///
  /// Uploads the image via Edge Function (required for private bucket),
  /// then updates the local cache with the new avatar URL.
  ///
  /// Requirements: 6.3 - Avatar upload via Edge Function
  Future<UserProfile> uploadAvatar({
    required String fileName,
    required List<int> bytes,
    required String contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    _ensureInitialized();

    final token = await _tokenStorage.getAccessToken();
    if (token == null) {
      throw const ApiException(
        type: ApiErrorType.unauthorized,
        message: 'Not authenticated',
      );
    }

    try {
      // Upload via Edge Function
      // The Edge Function updates the profile's avatar_url automatically
      await _supabaseStorage.uploadViaFunction(
        functionName: 'upload-avatar',
        accessToken: token,
        fileName: fileName,
        bytes: bytes,
        contentType: contentType,
        onProgress: onProgress,
      );

      // Refresh profile to get updated avatar_url
      final profile = await _fetchProfileFromServer();
      if (profile == null) {
        throw const ApiException(
          type: ApiErrorType.serverError,
          message: 'Failed to refresh profile after avatar upload',
        );
      }

      return profile;
    } on ApiException {
      rethrow;
    }
  }

  /// Gets a signed URL for the user's avatar.
  ///
  /// Required for accessing files in private buckets.
  ///
  /// Requirements: 6.4 - Signed URL for private avatar access
  Future<SignedUrlResult> getAvatarSignedUrl({
    required String avatarPath,
    int expiresIn = 3600,
  }) async {
    final token = await _tokenStorage.getAccessToken();
    if (token == null) {
      throw const ApiException(
        type: ApiErrorType.unauthorized,
        message: 'Not authenticated',
      );
    }

    // Extract bucket and path from avatar_url
    // Format: "user-avatars/userId/filename.jpg"
    final parts = avatarPath.split('/');
    if (parts.isEmpty) {
      throw const ApiException(
        type: ApiErrorType.badRequest,
        message: 'Invalid avatar path',
      );
    }

    final bucket = parts.first;
    final path = parts.skip(1).join('/');

    return _supabaseStorage.getSignedUrl(
      functionName: 'get-signed-url',
      accessToken: token,
      bucket: bucket,
      path: path,
      expiresIn: expiresIn,
    );
  }

  // ============================================================
  // Cache Management
  // ============================================================

  /// Clears the cached profile.
  Future<void> clearCache() async {
    _ensureInitialized();
    await _box!.delete(_profileKey);
    await _box!.delete(_lastFetchKey);
  }

  /// Gets the last fetch time.
  DateTime? getLastFetchTime() {
    _ensureInitialized();
    final lastFetchStr = _box!.get(_lastFetchKey);
    if (lastFetchStr == null) return null;

    try {
      return DateTime.parse(lastFetchStr);
    } on FormatException {
      return null;
    }
  }

  /// Whether the cache has a profile.
  bool get hasCachedProfile {
    _ensureInitialized();
    return _box!.containsKey(_profileKey);
  }

  /// Whether the cache is stale.
  bool get isCacheStale => _isCacheStale();

  // ============================================================
  // Cleanup
  // ============================================================

  /// Disposes resources.
  Future<void> dispose() async {
    await _box?.close();
    _isInitialized = false;
  }
}
