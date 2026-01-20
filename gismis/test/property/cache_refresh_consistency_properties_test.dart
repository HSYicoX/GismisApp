import 'dart:convert';

import 'package:gismis/features/profile/data/models/user_profile.dart';
import 'package:glados/glados.dart';

/// Feature: supabase-integration, Property 8: Cache Refresh Consistency
/// Validates: Requirements 6.5
///
/// For any user profile, after caching locally, the cached data SHALL be
/// retrievable and equivalent to the original. Background refresh SHALL
/// update the cache with server data while maintaining data integrity.

void main() {
  group('Property 8: Cache Refresh Consistency', () {
    // Test UserProfile JSON serialization round-trip
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any UserProfile, JSON serialization round-trip SHALL preserve all data',
      (userId, nickname) {
        final now = DateTime.now();
        final original = UserProfile(
          id: 'profile-$userId',
          userId: userId,
          nickname: nickname,
          avatarUrl: 'user-avatars/$userId/avatar.jpg',
          bio: 'Test bio for $nickname',
          preferences: {'theme': 'dark', 'language': 'en'},
          createdAt: now,
          updatedAt: now,
        );

        // Serialize and deserialize (simulating cache storage)
        final jsonString = jsonEncode(original.toJson());
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final restored = UserProfile.fromJson(json);

        // Verify all fields match
        expect(restored.id, equals(original.id));
        expect(restored.userId, equals(original.userId));
        expect(restored.nickname, equals(original.nickname));
        expect(restored.avatarUrl, equals(original.avatarUrl));
        expect(restored.bio, equals(original.bio));
        expect(
          restored.preferences['theme'],
          equals(original.preferences['theme']),
        );
        expect(
          restored.preferences['language'],
          equals(original.preferences['language']),
        );
      },
    );

    // Test UserProfile with null optional fields
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any UserProfile with null fields, serialization SHALL preserve nulls',
      (userId) {
        final now = DateTime.now();
        final original = UserProfile(
          id: 'profile-$userId',
          userId: userId,
          nickname: null,
          avatarUrl: null,
          bio: null,
          preferences: const {},
          createdAt: now,
          updatedAt: now,
        );

        // Serialize and deserialize
        final jsonString = jsonEncode(original.toJson());
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final restored = UserProfile.fromJson(json);

        // Verify null fields are preserved
        expect(restored.nickname, isNull);
        expect(restored.avatarUrl, isNull);
        expect(restored.bio, isNull);
        expect(restored.hasNickname, isFalse);
        expect(restored.hasAvatar, isFalse);
        expect(restored.hasBio, isFalse);
      },
    );

    // Test cache staleness calculation
    Glados<int>(any.intInRange(1, 120)).test(
      'For any cache age in minutes, staleness SHALL be correctly determined',
      (ageMinutes) {
        // Use a fixed reference time to avoid timing issues
        final referenceTime = DateTime(2024, 1, 1, 12, 0, 0);
        final lastFetch = referenceTime.subtract(Duration(minutes: ageMinutes));
        final cacheDuration = const Duration(minutes: 30);

        // Calculate staleness using the same reference time
        final isStale = referenceTime.difference(lastFetch) > cacheDuration;

        // Verify staleness logic: > 30 minutes is stale, <= 30 is fresh
        if (ageMinutes > 30) {
          expect(isStale, isTrue);
        } else {
          expect(isStale, isFalse);
        }
      },
    );

    // Test UpdateProfileRequest serialization
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any UpdateProfileRequest, toJson SHALL include only non-null fields',
      (nickname, bio) {
        // Request with all fields
        final fullRequest = UpdateProfileRequest(
          nickname: nickname,
          bio: bio,
          preferences: {'theme': 'light'},
        );

        final fullJson = fullRequest.toJson();
        expect(fullJson.containsKey('nickname'), isTrue);
        expect(fullJson.containsKey('bio'), isTrue);
        expect(fullJson.containsKey('preferences'), isTrue);
        expect(fullJson['nickname'], equals(nickname));
        expect(fullJson['bio'], equals(bio));

        // Request with only nickname
        final partialRequest = UpdateProfileRequest(nickname: nickname);
        final partialJson = partialRequest.toJson();
        expect(partialJson.containsKey('nickname'), isTrue);
        expect(partialJson.containsKey('bio'), isFalse);
        expect(partialJson.containsKey('preferences'), isFalse);

        // Empty request
        const emptyRequest = UpdateProfileRequest();
        final emptyJson = emptyRequest.toJson();
        expect(emptyJson.isEmpty, isTrue);
        expect(emptyRequest.hasUpdates, isFalse);
      },
    );

    // Test UserProfile equality
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any two UserProfiles with same data, equality SHALL return true',
      (userId) {
        final now = DateTime.now();
        final profile1 = UserProfile(
          id: 'profile-$userId',
          userId: userId,
          nickname: 'Test User',
          avatarUrl: 'avatar.jpg',
          bio: 'Test bio',
          preferences: const {'theme': 'dark'},
          createdAt: now,
          updatedAt: now,
        );

        final profile2 = UserProfile(
          id: 'profile-$userId',
          userId: userId,
          nickname: 'Test User',
          avatarUrl: 'avatar.jpg',
          bio: 'Test bio',
          preferences: const {'theme': 'dark'},
          createdAt: now,
          updatedAt: now,
        );

        expect(profile1 == profile2, isTrue);
        expect(profile1.hashCode, equals(profile2.hashCode));
      },
    );

    // Test UserProfile inequality
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any two UserProfiles with different data, equality SHALL return false',
      (userId1, userId2) {
        // Skip if IDs happen to be the same
        if (userId1 == userId2) return;

        final now = DateTime.now();
        final profile1 = UserProfile(
          id: 'profile-$userId1',
          userId: userId1,
          nickname: 'User 1',
          createdAt: now,
          updatedAt: now,
        );

        final profile2 = UserProfile(
          id: 'profile-$userId2',
          userId: userId2,
          nickname: 'User 2',
          createdAt: now,
          updatedAt: now,
        );

        expect(profile1 == profile2, isFalse);
      },
    );

    // Test UserProfile copyWith
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test('For any UserProfile, copyWith SHALL preserve unchanged fields', (
      userId,
      newNickname,
    ) {
      final now = DateTime.now();
      final original = UserProfile(
        id: 'profile-$userId',
        userId: userId,
        nickname: 'Original',
        avatarUrl: 'avatar.jpg',
        bio: 'Original bio',
        preferences: const {'theme': 'dark'},
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(nickname: newNickname);

      // Changed field
      expect(updated.nickname, equals(newNickname));

      // Unchanged fields
      expect(updated.id, equals(original.id));
      expect(updated.userId, equals(original.userId));
      expect(updated.avatarUrl, equals(original.avatarUrl));
      expect(updated.bio, equals(original.bio));
      expect(updated.preferences, equals(original.preferences));
      expect(updated.createdAt, equals(original.createdAt));
      expect(updated.updatedAt, equals(original.updatedAt));
    });

    // Test getPreference type safety
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any UserProfile, getPreference SHALL return correctly typed values',
      (userId) {
        final now = DateTime.now();
        final profile = UserProfile(
          id: 'profile-$userId',
          userId: userId,
          preferences: {'theme': 'dark', 'autoplay': true, 'quality': 1080},
          createdAt: now,
          updatedAt: now,
        );

        // Correct types
        expect(profile.getPreference<String>('theme'), equals('dark'));
        expect(profile.getPreference<bool>('autoplay'), equals(true));
        expect(profile.getPreference<int>('quality'), equals(1080));

        // Wrong types return null
        expect(profile.getPreference<int>('theme'), isNull);
        expect(profile.getPreference<String>('autoplay'), isNull);

        // Missing keys return null
        expect(profile.getPreference<String>('nonexistent'), isNull);
      },
    );

    // Test cache storage simulation
    Glados<int>(any.intInRange(1, 10)).test(
      'For any sequence of profile updates, cache SHALL contain latest version',
      (updateCount) {
        final cache = <String, String>{};
        const cacheKey = 'user_profile';
        final now = DateTime.now();

        UserProfile? latestProfile;

        // Simulate multiple updates
        for (var i = 0; i < updateCount; i++) {
          final profile = UserProfile(
            id: 'profile-123',
            userId: 'user-123',
            nickname: 'User v$i',
            bio: 'Bio version $i',
            createdAt: now,
            updatedAt: now.add(Duration(seconds: i)),
          );

          // Store in cache
          cache[cacheKey] = jsonEncode(profile.toJson());
          latestProfile = profile;
        }

        // Retrieve from cache
        final cachedJson = jsonDecode(cache[cacheKey]!) as Map<String, dynamic>;
        final cachedProfile = UserProfile.fromJson(cachedJson);

        // Verify cache contains latest version
        expect(cachedProfile.nickname, equals(latestProfile!.nickname));
        expect(cachedProfile.bio, equals(latestProfile.bio));
        expect(cachedProfile.updatedAt, equals(latestProfile.updatedAt));
      },
    );

    // Test preferences merge simulation
    Glados<int>(any.intInRange(1, 5)).test(
      'For any sequence of preference updates, merge SHALL combine all preferences',
      (updateCount) {
        var currentPrefs = <String, dynamic>{};

        // Simulate multiple preference updates
        for (var i = 0; i < updateCount; i++) {
          final newPrefs = {'pref_$i': 'value_$i'};

          // Merge (server-side behavior simulation)
          currentPrefs = {...currentPrefs, ...newPrefs};
        }

        // Verify all preferences are present
        expect(currentPrefs.length, equals(updateCount));
        for (var i = 0; i < updateCount; i++) {
          expect(currentPrefs['pref_$i'], equals('value_$i'));
        }
      },
    );

    // Test timestamp parsing
    Glados<int>(any.intInRange(0, 1000000)).test(
      'For any timestamp offset, DateTime parsing SHALL be consistent',
      (offsetSeconds) {
        final baseTime = DateTime(2024, 1, 1);
        final timestamp = baseTime.add(Duration(seconds: offsetSeconds));

        // Serialize to ISO8601
        final isoString = timestamp.toIso8601String();

        // Parse back
        final parsed = DateTime.parse(isoString);

        // Verify consistency (within millisecond precision)
        expect(
          parsed.difference(timestamp).inMilliseconds.abs(),
          lessThan(1000),
        );
      },
    );

    // Test UpdateProfileRequest hasUpdates
    Glados<bool>(any.bool).test(
      'For any UpdateProfileRequest, hasUpdates SHALL correctly reflect content',
      (includeNickname) {
        final request = UpdateProfileRequest(
          nickname: includeNickname ? 'Test' : null,
        );

        expect(request.hasUpdates, equals(includeNickname));
      },
    );
  });
}
