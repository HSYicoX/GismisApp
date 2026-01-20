import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'core/network/dio_client.dart';
import 'core/storage/hive_cache.dart';
import 'features/auth/domain/auth_providers.dart';

/// Main entry point for the Gismis anime tracker application.
///
/// Initializes:
/// - Hive for local caching
/// - ProviderScope for Riverpod state management
/// - GismisApp with routing and theming
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize cache service
  final cacheService = CacheService();
  await cacheService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        // Override with actual API configuration
        // In production, this would come from environment config
        dioClientConfigProvider.overrideWithValue(
          const DioClientConfig(
            baseUrl: 'https://api.gismis.app', // Replace with actual API URL
          ),
        ),
        // Provide the initialized cache service
        cacheServiceProvider.overrideWithValue(cacheService),
      ],
      child: const GismisApp(),
    ),
  );
}

/// Provider for the CacheService instance.
final cacheServiceProvider = Provider<CacheService>((ref) {
  // This will be overridden in main() with the initialized instance
  throw UnimplementedError('CacheService must be initialized in main()');
});
