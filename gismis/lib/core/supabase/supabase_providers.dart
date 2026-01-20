/// Riverpod providers for Supabase services.
///
/// This file provides the core Supabase providers:
/// - [supabaseConfigProvider]: Configuration for Supabase services
/// - [supabaseClientProvider]: HTTP client for PostgREST and Edge Functions
/// - [supabaseStorageProvider]: Storage service for file operations
///
/// Requirements: 1.1 - Supabase service providers
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_client.dart';
import 'supabase_config.dart';
import 'supabase_storage.dart';

/// Provider for Supabase configuration.
///
/// Uses self-hosted Supabase at https://api.haokir.com
/// Override this provider in tests or for different environments:
///
/// ```dart
/// // In main.dart for development
/// runApp(
///   ProviderScope(
///     overrides: [
///       supabaseConfigProvider.overrideWithValue(SupabaseConfig.dev()),
///     ],
///     child: const MyApp(),
///   ),
/// );
/// ```
final supabaseConfigProvider = Provider<SupabaseConfig>((ref) {
  // Self-hosted Supabase configuration
  return SupabaseConfig.standard(
    baseUrl: 'https://api.haokir.com',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY0Nzc3NjAwLCJleHAiOjE5MjI1NDQwMDB9.JQekgxRZBzi_pl2iLLXJw5yllgB5iKSvTOzoY6kYw3E',
  );
});

/// Provider for the Supabase HTTP client.
///
/// Creates a dedicated Dio instance configured for Supabase services:
/// - PostgREST queries with Range/Content-Range pagination
/// - Edge Function invocation with JWT authentication
///
/// Depends on [supabaseConfigProvider] for configuration.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  final config = ref.watch(supabaseConfigProvider);
  return SupabaseClient(config: config);
});

/// Provider for the Supabase Storage service.
///
/// Handles file operations with proper permission boundaries:
/// - Public bucket URLs (anime-covers, anime-banners)
/// - Private bucket uploads via Edge Functions (user-avatars)
/// - Signed URLs for private file access
///
/// Depends on [supabaseConfigProvider] for configuration.
final supabaseStorageProvider = Provider<SupabaseStorage>((ref) {
  final config = ref.watch(supabaseConfigProvider);
  return SupabaseStorage(config: config);
});
