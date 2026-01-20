/// Riverpod providers for Supabase repositories.
///
/// This file provides repository providers for all features that use Supabase:
/// - Anime Library (anime, seasons, episodes, source materials)
/// - Schedule
/// - Favorites (local-first with cloud sync)
/// - Profile
/// - AI Assistant
/// - Watch History
///
/// Requirements: 1.1 - Feature repository providers
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai_assistant/data/supabase_ai_repository.dart';
import '../../features/anime_library/data/anime_repository.dart';
import '../../features/anime_library/data/season_episode_repository.dart';
import '../../features/anime_library/data/source_material_repository.dart';
import '../../features/favorites/data/supabase_favorites_repository.dart';
import '../../features/favorites/data/sync_queue.dart';
import '../../features/profile/data/supabase_profile_repository.dart';
import '../../features/schedule/data/supabase_schedule_repository.dart';
import '../../features/watch_history/data/watch_history_repository.dart';
import '../storage/hive_cache.dart';
import '../storage/secure_storage.dart';
import 'supabase_providers.dart';

// ============================================================
// Service Providers (dependencies for repositories)
// ============================================================

/// Provider for the CacheService instance.
///
/// Must be overridden with an initialized instance in main.dart:
/// ```dart
/// final cacheService = CacheService();
/// await cacheService.initialize();
///
/// runApp(
///   ProviderScope(
///     overrides: [
///       cacheServiceProvider.overrideWithValue(cacheService),
///     ],
///     child: const MyApp(),
///   ),
/// );
/// ```
final cacheServiceProvider = Provider<CacheService>((ref) {
  throw UnimplementedError(
    'cacheServiceProvider must be overridden with an initialized CacheService',
  );
});

/// Provider for the SecureStorageService instance.
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Provider for the SyncQueue instance (favorites sync).
///
/// Must be overridden with an initialized instance in main.dart.
final syncQueueProvider = Provider<SyncQueue>((ref) {
  throw UnimplementedError(
    'syncQueueProvider must be overridden with an initialized SyncQueue',
  );
});

// ============================================================
// Anime Library Repositories
// ============================================================

/// Provider for the AnimeLibraryRepository.
///
/// Handles public read operations for anime data via PostgREST.
final animeLibraryRepositoryProvider = Provider<AnimeLibraryRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  return AnimeLibraryRepository(client: client, cache: cache);
});

/// Provider for the SeasonEpisodeRepository.
///
/// Handles public read operations for seasons and episodes via PostgREST.
final seasonEpisodeRepositoryProvider = Provider<SeasonEpisodeRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return SeasonEpisodeRepository(client: client);
});

/// Provider for the SourceMaterialRepository.
///
/// Handles public read operations for source materials via PostgREST.
final sourceMaterialRepositoryProvider = Provider<SourceMaterialRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return SourceMaterialRepository(client: client);
});

// ============================================================
// Schedule Repository
// ============================================================

/// Provider for the SupabaseScheduleRepository.
///
/// Handles public read operations for anime schedule via PostgREST.
final supabaseScheduleRepositoryProvider = Provider<SupabaseScheduleRepository>(
  (ref) {
    final client = ref.watch(supabaseClientProvider);
    return SupabaseScheduleRepository(client: client);
  },
);

// ============================================================
// User Data Repositories (require authentication)
// ============================================================

/// Provider for the SupabaseFavoritesRepository.
///
/// Implements local-first strategy with cloud sync via Edge Functions.
/// Requires initialization before use.
final supabaseFavoritesRepositoryProvider =
    Provider<SupabaseFavoritesRepository>((ref) {
      final client = ref.watch(supabaseClientProvider);
      final tokenStorage = ref.watch(secureStorageServiceProvider);
      final syncQueue = ref.watch(syncQueueProvider);
      return SupabaseFavoritesRepository(
        supabaseClient: client,
        tokenStorage: tokenStorage,
        syncQueue: syncQueue,
      );
    });

/// Provider for the SupabaseProfileRepository.
///
/// Handles user profile operations via Edge Functions with local caching.
/// Requires initialization before use.
final supabaseProfileRepositoryProvider = Provider<SupabaseProfileRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  final storage = ref.watch(supabaseStorageProvider);
  final tokenStorage = ref.watch(secureStorageServiceProvider);
  return SupabaseProfileRepository(
    supabaseClient: client,
    supabaseStorage: storage,
    tokenStorage: tokenStorage,
  );
});

/// Provider for the SupabaseAiRepository.
///
/// Handles AI chat streaming via Edge Functions with SSE.
final supabaseAiRepositoryProvider = Provider<SupabaseAiRepository>((ref) {
  final config = ref.watch(supabaseConfigProvider);
  final tokenStorage = ref.watch(secureStorageServiceProvider);
  return SupabaseAiRepository(config: config, tokenStorage: tokenStorage);
});

/// Provider for the WatchHistoryRepository.
///
/// Handles watch history operations via Edge Functions with local caching.
/// Requires initialization before use.
final watchHistoryRepositoryProvider = Provider<WatchHistoryRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final tokenStorage = ref.watch(secureStorageServiceProvider);
  return WatchHistoryRepository(
    supabaseClient: client,
    tokenStorage: tokenStorage,
  );
});
