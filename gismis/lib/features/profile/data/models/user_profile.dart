/// User profile model for Supabase integration.
///
/// Represents the user's profile data stored in the `user_profiles` table.
/// This model is used for profile operations via Edge Functions.
///
/// Requirements: 6.1
library;

import 'package:meta/meta.dart';

/// User profile data class.
///
/// Contains user profile information including nickname, avatar, bio,
/// and user preferences. All profile operations go through Edge Functions
/// for proper authentication and validation.
@immutable
class UserProfile {
  /// Creates a new user profile.
  const UserProfile({
    required this.id,
    required this.userId,
    this.nickname,
    this.avatarUrl,
    this.bio,
    this.preferences = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a UserProfile from JSON data.
  ///
  /// Expected JSON structure from Edge Function response:
  /// ```json
  /// {
  ///   "id": "uuid",
  ///   "user_id": "uuid",
  ///   "nickname": "string or null",
  ///   "avatar_url": "string or null",
  ///   "bio": "string or null",
  ///   "preferences": {},
  ///   "created_at": "ISO8601 timestamp",
  ///   "updated_at": "ISO8601 timestamp"
  /// }
  /// ```
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      preferences: (json['preferences'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// The unique profile ID.
  final String id;

  /// The user ID this profile belongs to.
  final String userId;

  /// The user's display nickname.
  final String? nickname;

  /// The URL or path to the user's avatar image.
  ///
  /// For private bucket storage, this is the path within the bucket.
  /// Use `get-signed-url` Edge Function to get a signed URL for access.
  final String? avatarUrl;

  /// The user's bio/description.
  final String? bio;

  /// User preferences as a key-value map.
  ///
  /// Allowed keys: theme, language, notifications, autoplay, quality,
  /// subtitle, displayMode.
  final Map<String, dynamic> preferences;

  /// When the profile was created.
  final DateTime createdAt;

  /// When the profile was last updated.
  final DateTime updatedAt;

  /// Converts this profile to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'bio': bio,
      'preferences': preferences,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy of this profile with the given fields replaced.
  UserProfile copyWith({
    String? id,
    String? userId,
    String? nickname,
    String? avatarUrl,
    String? bio,
    Map<String, dynamic>? preferences,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Whether the user has set a nickname.
  bool get hasNickname => nickname != null && nickname!.isNotEmpty;

  /// Whether the user has set an avatar.
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  /// Whether the user has set a bio.
  bool get hasBio => bio != null && bio!.isNotEmpty;

  /// Gets a preference value by key.
  T? getPreference<T>(String key) {
    final value = preferences[key];
    if (value is T) return value;
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UserProfile) return false;
    return id == other.id &&
        userId == other.userId &&
        nickname == other.nickname &&
        avatarUrl == other.avatarUrl &&
        bio == other.bio &&
        _mapEquals(preferences, other.preferences) &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    // Sort preferences keys for consistent hashCode calculation
    final sortedKeys = preferences.keys.toList()..sort();
    final sortedEntries = sortedKeys.map((k) => MapEntry(k, preferences[k]));
    return Object.hash(
      id,
      userId,
      nickname,
      avatarUrl,
      bio,
      Object.hashAll(sortedEntries.map((e) => Object.hash(e.key, e.value))),
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, userId: $userId, nickname: $nickname, '
        'avatarUrl: $avatarUrl, bio: $bio)';
  }

  /// Helper to compare maps for equality.
  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Request data for updating a user profile.
///
/// Used when calling the `update-profile` Edge Function.
@immutable
class UpdateProfileRequest {
  /// Creates an update profile request.
  const UpdateProfileRequest({this.nickname, this.bio, this.preferences});

  /// The new nickname (null to keep current, empty string to clear).
  final String? nickname;

  /// The new bio (null to keep current, empty string to clear).
  final String? bio;

  /// Preferences to update (merged with existing preferences).
  final Map<String, dynamic>? preferences;

  /// Converts this request to JSON for the Edge Function.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (nickname != null) json['nickname'] = nickname;
    if (bio != null) json['bio'] = bio;
    if (preferences != null) json['preferences'] = preferences;
    return json;
  }

  /// Whether this request has any updates.
  bool get hasUpdates => nickname != null || bio != null || preferences != null;

  @override
  String toString() {
    return 'UpdateProfileRequest(nickname: $nickname, bio: $bio, '
        'preferences: $preferences)';
  }
}
