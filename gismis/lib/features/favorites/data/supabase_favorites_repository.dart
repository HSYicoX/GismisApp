import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/models/anime.dart';
import 'models/favorite_anime.dart';
import 'sync_queue.dart';

/// Repository for managing user's favorite anime with local-first + cloud sync.
///
/// This repository implements a local-first strategy:
/// - All reads return local data immediately
/// - All writes save to local storage first
/// - Background sync pushes changes to Supabase via Edge Functions
/// - Server-wins conflict resolution for same anime
///
/// Requirements: 5.1, 5.2, 5.3, 5.4, 5.5
class SupabaseFavoritesRepository {
  SupabaseFavoritesRepository({
    required SupabaseClient supabaseClient,
    required SecureStorageService tokenStorage,
    required SyncQueue syncQueue,
    String boxName = 'supabase_favorites',
  }) : _supabaseClient = supabaseClient,
       _tokenStorage = tokenStorage,
       _syncQueue = syncQueue,
       _boxName = boxName;

  final SupabaseClient _supabaseClient;
  final SecureStorageService _tokenStorage;
  final SyncQueue _syncQueue;
  final String _boxName;

  Box<String>? _box;
  bool _isInitialized = false;

  static const _uuid = Uuid();

  /// Initialize the repository storage.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _box = await Hive.openBox<String>(_boxName);
    await _syncQueue.initialize();
    _isInitialized = true;
  }

  void _ensureInitialized() {
    if (!_isInitialized || _box == null) {
      throw StateError(
        'SupabaseFavoritesRepository not initialized. Call initialize() first.',
      );
    }
  }

  // ============================================================
  // Local-First Read Operations
  // ============================================================

  /// Gets all favorites from local storage (local-first).
  ///
  /// Returns cached favorites immediately, then triggers background sync.
  /// Requirements: 5.1 - Local-first read
  Future<List<FavoriteAnime>> getFavorites() async {
    _ensureInitialized();

    // Return local data immediately
    final favorites = _getLocalFavorites();

    // Trigger background sync (fire and forget)
    _syncFromServer();

    return favorites;
  }

  /// Gets local favorites without triggering sync.
  List<FavoriteAnime> _getLocalFavorites() {
    _ensureInitialized();
    final favorites = <FavoriteAnime>[];

    for (final key in _box!.keys) {
      final jsonString = _box!.get(key);
      if (jsonString != null) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          favorites.add(FavoriteAnime.fromJson(json));
        } on FormatException {
          debugPrint('SupabaseFavoritesRepository: Skipping malformed entry');
        }
      }
    }

    // Sort by custom order, then by added date
    favorites.sort((a, b) {
      if (a.customOrder != null && b.customOrder != null) {
        return a.customOrder!.compareTo(b.customOrder!);
      }
      if (a.customOrder != null) return -1;
      if (b.customOrder != null) return 1;
      return b.addedAt.compareTo(a.addedAt);
    });

    return favorites;
  }

  /// Checks if an anime is in favorites.
  bool isFavorite(String animeId) {
    _ensureInitialized();
    return _box!.containsKey(animeId);
  }

  /// Gets a specific favorite by anime ID.
  FavoriteAnime? getFavorite(String animeId) {
    _ensureInitialized();
    final jsonString = _box!.get(animeId);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return FavoriteAnime.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  // ============================================================
  // Local-First Write Operations
  // ============================================================

  /// Adds an anime to favorites (local-first).
  ///
  /// Saves to local storage immediately, then queues for sync.
  /// Requirements: 5.1 - Local-first write
  Future<void> addFavorite(FavoriteAnime favorite) async {
    _ensureInitialized();

    // Save to local storage immediately
    final jsonString = jsonEncode(favorite.toJson());
    await _box!.put(favorite.animeId, jsonString);

    // Queue sync operation
    final operation = SyncOperation(
      id: _uuid.v4(),
      type: SyncType.addFavorite,
      data: favorite.toJson(),
      timestamp: DateTime.now(),
    );
    await _syncQueue.enqueue(operation);

    // Try to process queue immediately if online
    _processSyncQueueInBackground();
  }

  /// Adds an anime to favorites from an Anime model.
  Future<void> addFavoriteFromAnime(Anime anime, {int? customOrder}) async {
    final favorite = FavoriteAnime.fromAnime(anime, customOrder: customOrder);
    await addFavorite(favorite);
  }

  /// Removes an anime from favorites (local-first).
  ///
  /// Removes from local storage immediately, then queues for sync.
  /// Requirements: 5.1 - Local-first write
  Future<void> removeFavorite(String animeId) async {
    _ensureInitialized();

    // Remove from local storage immediately
    await _box!.delete(animeId);

    // Queue sync operation
    final operation = SyncOperation(
      id: _uuid.v4(),
      type: SyncType.removeFavorite,
      data: {'anime_id': animeId},
      timestamp: DateTime.now(),
    );
    await _syncQueue.enqueue(operation);

    // Try to process queue immediately if online
    _processSyncQueueInBackground();
  }

  /// Toggles favorite status for an anime.
  ///
  /// Returns true if the anime is now a favorite, false otherwise.
  Future<bool> toggleFavorite(Anime anime) async {
    if (isFavorite(anime.id)) {
      await removeFavorite(anime.id);
      return false;
    } else {
      await addFavoriteFromAnime(anime);
      return true;
    }
  }

  /// Updates the custom order of favorites.
  Future<void> updateOrder(List<String> animeIds) async {
    _ensureInitialized();

    // Update local storage with new order
    for (var i = 0; i < animeIds.length; i++) {
      final animeId = animeIds[i];
      final existing = getFavorite(animeId);
      if (existing != null) {
        final updated = existing.copyWith(customOrder: i);
        final jsonString = jsonEncode(updated.toJson());
        await _box!.put(animeId, jsonString);
      }
    }

    // Queue sync operation
    final operation = SyncOperation(
      id: _uuid.v4(),
      type: SyncType.updateOrder,
      data: {'anime_ids': animeIds},
      timestamp: DateTime.now(),
    );
    await _syncQueue.enqueue(operation);

    _processSyncQueueInBackground();
  }

  // ============================================================
  // Cloud Sync Operations
  // ============================================================

  /// Syncs favorites from server (background operation).
  ///
  /// Uses server-wins strategy for conflicts.
  /// Requirements: 5.2, 5.4 - Cloud sync with server-wins
  Future<void> _syncFromServer() async {
    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null) {
        debugPrint('SupabaseFavoritesRepository: No token, skipping sync');
        return;
      }

      final response = await _supabaseClient.callFunction<List<dynamic>>(
        'get-favorites',
        accessToken: token,
      );

      final serverFavorites = (response.data ?? [])
          .map((e) => FavoriteAnime.fromJson(e as Map<String, dynamic>))
          .toList();

      // Server-wins merge strategy
      await _mergeServerFavorites(serverFavorites);
    } on ApiException catch (e) {
      debugPrint('SupabaseFavoritesRepository: Sync failed: ${e.message}');
    } on Exception catch (e) {
      debugPrint('SupabaseFavoritesRepository: Sync error: $e');
    }
  }

  /// Merges server favorites with local (server-wins for same anime).
  Future<void> _mergeServerFavorites(
    List<FavoriteAnime> serverFavorites,
  ) async {
    _ensureInitialized();

    // Create a map of server favorites by anime ID
    final serverMap = {for (final f in serverFavorites) f.animeId: f};

    // Get current local favorites
    final localFavorites = _getLocalFavorites();

    // Server-wins: update local with server data
    for (final serverFav in serverFavorites) {
      final synced = serverFav.markSynced();
      final jsonString = jsonEncode(synced.toJson());
      await _box!.put(serverFav.animeId, jsonString);
    }

    // Keep local-only favorites that haven't been synced yet
    // (they might be pending in the sync queue)
    for (final localFav in localFavorites) {
      if (!serverMap.containsKey(localFav.animeId) && !localFav.isSynced) {
        // Keep unsynced local favorites
        continue;
      }
      if (!serverMap.containsKey(localFav.animeId) && localFav.isSynced) {
        // Server removed this favorite, remove locally too
        await _box!.delete(localFav.animeId);
      }
    }
  }

  /// Processes the sync queue (call when online).
  ///
  /// Requirements: 5.3, 5.5 - Edge Function sync with offline queue
  Future<void> processSyncQueue() async {
    final token = await _tokenStorage.getAccessToken();
    if (token == null) {
      debugPrint('SupabaseFavoritesRepository: No token, cannot process queue');
      return;
    }

    final operations = _syncQueue.retryable;
    if (operations.isEmpty) return;

    try {
      final response = await _supabaseClient.callFunction<Map<String, dynamic>>(
        'sync-favorites',
        accessToken: token,
        data: {'operations': operations.map((o) => o.toJson()).toList()},
      );

      // Check response for success
      final success = response.data?['success'] as bool? ?? false;
      if (success) {
        // Clear processed operations
        await _syncQueue.clearProcessed(operations);

        // Mark local favorites as synced
        for (final op in operations) {
          if (op.type == SyncType.addFavorite) {
            final animeId = op.data['anime_id'] as String?;
            if (animeId != null) {
              final existing = getFavorite(animeId);
              if (existing != null) {
                final synced = existing.markSynced();
                final jsonString = jsonEncode(synced.toJson());
                await _box!.put(animeId, jsonString);
              }
            }
          }
        }
      } else {
        // Handle partial failures
        final errors = response.data?['errors'] as List<dynamic>? ?? [];
        for (var i = 0; i < operations.length; i++) {
          if (i < errors.length && errors[i] != null) {
            final errorMsg = errors[i].toString();
            final updated = operations[i].withError(errorMsg);
            await _syncQueue.update(updated);
          } else {
            await _syncQueue.dequeue(operations[i].id);
          }
        }
      }
    } on ApiException catch (e) {
      debugPrint(
        'SupabaseFavoritesRepository: Queue processing failed: ${e.message}',
      );
      // Update retry counts for all operations
      for (final op in operations) {
        final updated = op.withError(e.message);
        await _syncQueue.update(updated);
      }
    } on Exception catch (e) {
      debugPrint('SupabaseFavoritesRepository: Queue error: $e');
    }
  }

  /// Processes sync queue in background (fire and forget).
  void _processSyncQueueInBackground() {
    Future.microtask(() async {
      try {
        await processSyncQueue();
      } on Exception catch (e) {
        debugPrint('SupabaseFavoritesRepository: Background sync error: $e');
      }
    });
  }

  // ============================================================
  // Queue Status
  // ============================================================

  /// Gets the number of pending sync operations.
  int get pendingSyncCount => _syncQueue.pendingCount;

  /// Whether there are pending sync operations.
  bool get hasPendingSync => _syncQueue.hasPending;

  /// Gets failed sync operations.
  List<SyncOperation> get failedOperations => _syncQueue.failed;

  /// Clears failed operations from the queue.
  Future<void> clearFailedOperations() async {
    await _syncQueue.purgeFailed();
  }

  // ============================================================
  // Cleanup
  // ============================================================

  /// Clears all local favorites data.
  Future<void> clearLocal() async {
    _ensureInitialized();
    await _box!.clear();
  }

  /// Disposes resources.
  Future<void> dispose() async {
    await _box?.close();
    await _syncQueue.dispose();
    _isInitialized = false;
  }
}
