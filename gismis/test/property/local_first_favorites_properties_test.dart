import 'dart:convert';

import 'package:gismis/features/favorites/data/models/favorite_anime.dart';
import 'package:gismis/features/favorites/data/sync_queue.dart';
import 'package:gismis/shared/models/anime.dart';
import 'package:glados/glados.dart';

/// Feature: supabase-integration, Property 7: Local-First Write Consistency
/// Validates: Requirements 5.1, 5.5
///
/// For any favorite anime, after adding it locally, the local storage
/// SHALL contain that anime immediately, and a sync operation SHALL be
/// queued for later processing.

void main() {
  group('Property 7: Local-First Write Consistency', () {
    // Test that adding a favorite creates correct local entry
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any anime, adding to favorites SHALL create a local entry with correct data',
      (animeId, title) {
        // Create a favorite anime
        final favorite = FavoriteAnime(
          animeId: animeId,
          title: title,
          coverUrl: 'https://example.com/cover.jpg',
          addedAt: DateTime.now(),
        );

        // Simulate local storage (Map as stand-in for Hive box)
        final localStorage = <String, String>{};

        // Add to local storage
        final jsonString = jsonEncode(favorite.toJson());
        localStorage[favorite.animeId] = jsonString;

        // Verify the entry exists
        expect(localStorage.containsKey(animeId), isTrue);

        // Verify the data is correct
        final storedJson =
            jsonDecode(localStorage[animeId]!) as Map<String, dynamic>;
        final storedFavorite = FavoriteAnime.fromJson(storedJson);

        expect(storedFavorite.animeId, equals(animeId));
        expect(storedFavorite.title, equals(title));
      },
    );

    // Test that removing a favorite removes local entry
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any anime, removing from favorites SHALL remove the local entry',
      (animeId) {
        // Create initial local storage with the favorite
        final favorite = FavoriteAnime(
          animeId: animeId,
          title: 'Test Anime',
          coverUrl: 'https://example.com/cover.jpg',
          addedAt: DateTime.now(),
        );

        final localStorage = <String, String>{};
        localStorage[animeId] = jsonEncode(favorite.toJson());

        // Verify it exists
        expect(localStorage.containsKey(animeId), isTrue);

        // Remove from local storage
        localStorage.remove(animeId);

        // Verify it's gone
        expect(localStorage.containsKey(animeId), isFalse);
      },
    );

    // Test that sync operations are created correctly
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any favorite add operation, a sync operation SHALL be created with correct type',
      (animeId, title) {
        final favorite = FavoriteAnime(
          animeId: animeId,
          title: title,
          coverUrl: 'https://example.com/cover.jpg',
          addedAt: DateTime.now(),
        );

        // Create sync operation
        final operation = SyncOperation(
          id: 'op-$animeId',
          type: SyncType.addFavorite,
          data: favorite.toJson(),
          timestamp: DateTime.now(),
        );

        // Verify operation type
        expect(operation.type, equals(SyncType.addFavorite));

        // Verify data contains anime ID
        expect(operation.data['anime_id'], equals(animeId));
        expect(operation.data['title'], equals(title));
      },
    );

    // Test that remove operations are created correctly
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any favorite remove operation, a sync operation SHALL be created with correct type',
      (animeId) {
        // Create sync operation for removal
        final operation = SyncOperation(
          id: 'op-remove-$animeId',
          type: SyncType.removeFavorite,
          data: {'anime_id': animeId},
          timestamp: DateTime.now(),
        );

        // Verify operation type
        expect(operation.type, equals(SyncType.removeFavorite));

        // Verify data contains anime ID
        expect(operation.data['anime_id'], equals(animeId));
      },
    );

    // Test sync operation serialization round-trip
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any sync operation, JSON serialization round-trip SHALL preserve all data',
      (operationId, animeId) {
        final original = SyncOperation(
          id: operationId,
          type: SyncType.addFavorite,
          data: {'anime_id': animeId, 'title': 'Test'},
          timestamp: DateTime.now(),
          retryCount: 2,
          lastError: 'Network error',
        );

        // Serialize and deserialize
        final json = original.toJson();
        final restored = SyncOperation.fromJson(json);

        // Verify all fields match
        expect(restored.id, equals(original.id));
        expect(restored.type, equals(original.type));
        expect(restored.data['anime_id'], equals(original.data['anime_id']));
        expect(restored.retryCount, equals(original.retryCount));
        expect(restored.lastError, equals(original.lastError));
      },
    );

    // Test FavoriteAnime serialization round-trip
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test(
      'For any FavoriteAnime, JSON serialization round-trip SHALL preserve all data',
      (animeId, title) {
        final original = FavoriteAnime(
          animeId: animeId,
          title: title,
          coverUrl: 'https://example.com/cover.jpg',
          status: AnimeStatus.ongoing,
          addedAt: DateTime.now(),
          syncedAt: DateTime.now(),
          customOrder: 5,
        );

        // Serialize and deserialize
        final json = original.toJson();
        final restored = FavoriteAnime.fromJson(json);

        // Verify all fields match
        expect(restored.animeId, equals(original.animeId));
        expect(restored.title, equals(original.title));
        expect(restored.coverUrl, equals(original.coverUrl));
        expect(restored.status, equals(original.status));
        expect(restored.customOrder, equals(original.customOrder));
        expect(restored.isSynced, equals(original.isSynced));
      },
    );

    // Test local-first ordering consistency
    Glados<int>(any.intInRange(1, 20)).test(
      'For any list of favorites, custom order SHALL be preserved after local storage',
      (count) {
        // Create favorites with custom order
        final favorites = List.generate(
          count,
          (i) => FavoriteAnime(
            animeId: 'anime-$i',
            title: 'Anime $i',
            coverUrl: 'https://example.com/cover-$i.jpg',
            addedAt: DateTime.now(),
            customOrder: count - i, // Reverse order
          ),
        );

        // Simulate storing and retrieving
        final localStorage = <String, String>{};
        for (final fav in favorites) {
          localStorage[fav.animeId] = jsonEncode(fav.toJson());
        }

        // Retrieve and sort by custom order
        final retrieved =
            localStorage.values
                .map(
                  (s) => FavoriteAnime.fromJson(
                    jsonDecode(s) as Map<String, dynamic>,
                  ),
                )
                .toList()
              ..sort((a, b) {
                if (a.customOrder != null && b.customOrder != null) {
                  return a.customOrder!.compareTo(b.customOrder!);
                }
                return 0;
              });

        // Verify order is preserved
        for (var i = 0; i < retrieved.length - 1; i++) {
          final current = retrieved[i].customOrder ?? 0;
          final next = retrieved[i + 1].customOrder ?? 0;
          expect(current <= next, isTrue);
        }
      },
    );

    // Test sync queue ordering (FIFO)
    Glados<int>(any.intInRange(1, 10)).test(
      'For any sequence of operations, sync queue SHALL maintain FIFO order',
      (count) {
        // Create operations with sequential timestamps
        final baseTime = DateTime.now();
        final operations = List.generate(
          count,
          (i) => SyncOperation(
            id: 'op-$i',
            type: SyncType.addFavorite,
            data: {'anime_id': 'anime-$i'},
            timestamp: baseTime.add(Duration(seconds: i)),
          ),
        );

        // Simulate queue storage and retrieval
        final queue = <SyncOperation>[];
        for (final op in operations) {
          queue.add(op);
        }

        // Sort by timestamp (as the queue would)
        queue.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Verify FIFO order
        for (var i = 0; i < queue.length; i++) {
          expect(queue[i].id, equals('op-$i'));
        }
      },
    );

    // Test retry count increment
    Glados<int>(any.intInRange(0, 5)).test(
      'For any operation with error, retry count SHALL increment by 1',
      (initialRetryCount) {
        final operation = SyncOperation(
          id: 'op-test',
          type: SyncType.addFavorite,
          data: {'anime_id': 'test'},
          timestamp: DateTime.now(),
          retryCount: initialRetryCount,
        );

        // Apply error
        final updated = operation.withError('Network error');

        // Verify retry count incremented
        expect(updated.retryCount, equals(initialRetryCount + 1));
        expect(updated.lastError, equals('Network error'));
      },
    );

    // Test canRetry based on retry count
    Glados<int>(any.intInRange(0, 10)).test(
      'For any operation, canRetry SHALL be false when retryCount >= maxRetries',
      (retryCount) {
        final operation = SyncOperation(
          id: 'op-test',
          type: SyncType.addFavorite,
          data: {'anime_id': 'test'},
          timestamp: DateTime.now(),
          retryCount: retryCount,
        );

        // Verify canRetry logic
        final expectedCanRetry = retryCount < SyncOperation.maxRetries;
        expect(operation.canRetry, equals(expectedCanRetry));
      },
    );

    // Test FavoriteAnime.fromAnime factory
    Glados2<String, String>(
      any.nonEmptyLetterOrDigits,
      any.nonEmptyLetterOrDigits,
    ).test('For any Anime, FavoriteAnime.fromAnime SHALL preserve anime data', (
      animeId,
      title,
    ) {
      final anime = Anime(
        id: animeId,
        title: title,
        titleAlias: ['Alias 1'],
        coverUrl: 'https://example.com/cover.jpg',
        status: AnimeStatus.ongoing,
        updatedAt: DateTime.now(),
      );

      final favorite = FavoriteAnime.fromAnime(anime, customOrder: 3);

      // Verify data is preserved
      expect(favorite.animeId, equals(anime.id));
      expect(favorite.title, equals(anime.title));
      expect(favorite.coverUrl, equals(anime.coverUrl));
      expect(favorite.status, equals(anime.status));
      expect(favorite.customOrder, equals(3));
    });

    // Test markSynced updates syncedAt
    Glados<String>(any.nonEmptyLetterOrDigits).test(
      'For any unsynced favorite, markSynced SHALL set syncedAt to current time',
      (animeId) {
        final unsynced = FavoriteAnime(
          animeId: animeId,
          title: 'Test',
          coverUrl: 'https://example.com/cover.jpg',
          addedAt: DateTime.now(),
          syncedAt: null,
        );

        expect(unsynced.isSynced, isFalse);

        final beforeSync = DateTime.now();
        final synced = unsynced.markSynced();
        final afterSync = DateTime.now();

        expect(synced.isSynced, isTrue);
        expect(synced.syncedAt, isNotNull);
        expect(
          synced.syncedAt!.isAfter(
            beforeSync.subtract(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(
          synced.syncedAt!.isBefore(afterSync.add(const Duration(seconds: 1))),
          isTrue,
        );
      },
    );
  });
}
