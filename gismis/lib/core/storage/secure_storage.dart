import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../shared/models/auth_tokens.dart';

/// SecureStorageService provides secure storage for sensitive data like JWT tokens.
///
/// Uses flutter_secure_storage which encrypts data using:
/// - iOS: Keychain
/// - Android: AES encryption with KeyStore
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _expiresAtKey = 'expires_at';
  static const String _tokensKey = 'auth_tokens';

  final FlutterSecureStorage _storage;

  // ============================================================
  // Token Storage (Combined)
  // ============================================================

  /// Save authentication tokens securely.
  Future<void> saveTokens(AuthTokens tokens) async {
    final jsonString = jsonEncode(tokens.toJson());
    await _storage.write(key: _tokensKey, value: jsonString);
  }

  /// Retrieve stored authentication tokens.
  /// Returns null if no tokens are stored.
  Future<AuthTokens?> getTokens() async {
    final jsonString = await _storage.read(key: _tokensKey);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return AuthTokens.fromJson(json);
    } catch (e) {
      // If parsing fails, clear corrupted data
      await clearTokens();
      return null;
    }
  }

  /// Clear all stored tokens.
  Future<void> clearTokens() async {
    await _storage.delete(key: _tokensKey);
    // Also clear legacy individual keys if they exist
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _expiresAtKey);
  }

  // ============================================================
  // Individual Token Access (for convenience)
  // ============================================================

  /// Get only the access token.
  Future<String?> getAccessToken() async {
    final tokens = await getTokens();
    return tokens?.accessToken;
  }

  /// Get only the refresh token.
  Future<String?> getRefreshToken() async {
    final tokens = await getTokens();
    return tokens?.refreshToken;
  }

  /// Check if tokens exist and are not expired.
  Future<bool> hasValidTokens() async {
    final tokens = await getTokens();
    if (tokens == null) return false;
    return !tokens.isExpired;
  }

  /// Check if tokens exist (regardless of expiration).
  Future<bool> hasTokens() async {
    final tokens = await getTokens();
    return tokens != null;
  }

  /// Check if tokens are expiring soon (within 5 minutes).
  Future<bool> areTokensExpiringSoon() async {
    final tokens = await getTokens();
    if (tokens == null) return false;
    return tokens.isExpiringSoon;
  }

  // ============================================================
  // Generic Secure Storage
  // ============================================================

  /// Store a generic secure value.
  Future<void> setSecureValue(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Retrieve a generic secure value.
  Future<String?> getSecureValue(String key) async {
    return _storage.read(key: key);
  }

  /// Delete a generic secure value.
  Future<void> deleteSecureValue(String key) async {
    await _storage.delete(key: key);
  }

  /// Clear all secure storage data.
  /// Use with caution - this removes ALL stored data.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
