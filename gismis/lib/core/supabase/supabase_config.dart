/// Supabase configuration for self-hosted environment.
///
/// This class provides centralized configuration for all Supabase services,
/// supporting both standard Kong gateway deployments and custom path configurations.
///
/// Key constraints:
/// - Only uses anonKey for public read operations
/// - NEVER includes service_role key (server-side only)
/// - All private operations go through Edge Functions
library;

/// Self-hosted Supabase configuration.
///
/// Supports two deployment modes:
/// - [SupabaseConfig.standard]: Standard Kong gateway with conventional paths
/// - [SupabaseConfig.custom]: Custom paths for non-standard deployments
class SupabaseConfig {
  const SupabaseConfig._({
    required this.restUrl,
    required this.storageUrl,
    required this.functionsUrl,
    required this.realtimeUrl,
    required this.anonKey,
  });

  /// PostgREST API URL for database queries.
  final String restUrl;

  /// Storage API URL for file operations.
  final String storageUrl;

  /// Edge Functions URL for serverless functions.
  final String functionsUrl;

  /// Realtime WebSocket URL for subscriptions.
  final String realtimeUrl;

  /// Anonymous key for public read operations.
  ///
  /// This key is safe to include in client code as it only allows
  /// operations permitted by Row Level Security (RLS) policies.
  final String anonKey;

  /// Creates configuration for standard Kong gateway deployment.
  ///
  /// Use this factory when your Supabase instance uses the standard
  /// Kong gateway with conventional path prefixes:
  /// - `/rest/v1` for PostgREST
  /// - `/storage/v1` for Storage
  /// - `/functions/v1` for Edge Functions
  /// - `/realtime/v1` for Realtime (WebSocket)
  ///
  /// Example:
  /// ```dart
  /// final config = SupabaseConfig.standard(
  ///   baseUrl: 'https://api.haokir.com',
  ///   anonKey: 'your-anon-key',
  /// );
  /// ```
  factory SupabaseConfig.standard({
    required String baseUrl,
    required String anonKey,
  }) {
    // Remove trailing slash if present
    final normalizedUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final uri = Uri.parse(normalizedUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';

    return SupabaseConfig._(
      restUrl: '$normalizedUrl/rest/v1',
      storageUrl: '$normalizedUrl/storage/v1',
      functionsUrl: '$normalizedUrl/functions/v1',
      realtimeUrl: '$wsScheme://${uri.host}/realtime/v1',
      anonKey: anonKey,
    );
  }

  /// Creates configuration with custom service URLs.
  ///
  /// Use this factory when your Supabase instance uses non-standard
  /// paths or separate domains for different services.
  ///
  /// Example:
  /// ```dart
  /// final config = SupabaseConfig.custom(
  ///   restUrl: 'https://db.example.com/v1',
  ///   storageUrl: 'https://storage.example.com/v1',
  ///   functionsUrl: 'https://functions.example.com/v1',
  ///   realtimeUrl: 'wss://realtime.example.com/v1',
  ///   anonKey: 'your-anon-key',
  /// );
  /// ```
  factory SupabaseConfig.custom({
    required String restUrl,
    required String storageUrl,
    required String functionsUrl,
    required String realtimeUrl,
    required String anonKey,
  }) => SupabaseConfig._(
    restUrl: restUrl,
    storageUrl: storageUrl,
    functionsUrl: functionsUrl,
    realtimeUrl: realtimeUrl,
    anonKey: anonKey,
  );

  /// Creates production configuration from environment variables.
  ///
  /// Loads configuration from compile-time environment variables:
  /// - `SUPABASE_URL`: Base URL (default: 'https://api.haokir.com')
  /// - `SUPABASE_ANON_KEY`: Anonymous key (required)
  ///
  /// To set environment variables during build:
  /// ```bash
  /// flutter run --dart-define=SUPABASE_URL=https://api.example.com \
  ///             --dart-define=SUPABASE_ANON_KEY=your-key
  /// ```
  factory SupabaseConfig.prod() => SupabaseConfig.standard(
    baseUrl: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://api.haokir.com',
    ),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  /// Creates development configuration.
  ///
  /// Uses localhost URLs for local Supabase development.
  factory SupabaseConfig.dev({String? anonKey}) => SupabaseConfig.standard(
    baseUrl: 'http://localhost:54321',
    anonKey:
        anonKey ??
        const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
  );

  /// Creates staging configuration from environment variables.
  factory SupabaseConfig.staging() => SupabaseConfig.standard(
    baseUrl: const String.fromEnvironment(
      'SUPABASE_STAGING_URL',
      defaultValue: 'https://staging-api.haokir.com',
    ),
    anonKey: const String.fromEnvironment('SUPABASE_STAGING_ANON_KEY'),
  );

  /// Whether the configuration has a valid anon key.
  bool get hasValidAnonKey => anonKey.isNotEmpty;

  @override
  String toString() =>
      'SupabaseConfig('
      'restUrl: $restUrl, '
      'storageUrl: $storageUrl, '
      'functionsUrl: $functionsUrl, '
      'realtimeUrl: $realtimeUrl, '
      'hasAnonKey: ${anonKey.isNotEmpty})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupabaseConfig &&
          runtimeType == other.runtimeType &&
          restUrl == other.restUrl &&
          storageUrl == other.storageUrl &&
          functionsUrl == other.functionsUrl &&
          realtimeUrl == other.realtimeUrl &&
          anonKey == other.anonKey;

  @override
  int get hashCode =>
      restUrl.hashCode ^
      storageUrl.hashCode ^
      functionsUrl.hashCode ^
      realtimeUrl.hashCode ^
      anonKey.hashCode;
}
