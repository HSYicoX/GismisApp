import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme/app_theme.dart';

/// The root widget of the Gismis anime tracker application.
///
/// This widget sets up:
/// - MaterialApp.router with GoRouter for navigation
/// - AppTheme for consistent styling
/// - ProviderScope is expected to be wrapped externally in main.dart
///
/// Requirements: 8.1, 8.2, 8.3
/// - Soft, natural color palette
/// - Artistic/serif fonts for titles
/// - Magazine-like layouts
class GismisApp extends ConsumerWidget {
  const GismisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Gismis',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) {
        // Apply any global overlays or wrappers here
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

/// Extension on GoRouter for common navigation patterns.
extension GoRouterExtension on GoRouter {
  /// Navigate to anime detail page.
  void goToAnimeDetail(String animeId) {
    go(AppRoutes.animeDetailPath(animeId));
  }

  /// Navigate to anime AI page.
  void goToAnimeAi(String animeId) {
    go(AppRoutes.animeAiPath(animeId));
  }
}

/// Extension on BuildContext for easy navigation.
extension NavigationExtension on BuildContext {
  /// Navigate to anime detail page.
  void goToAnimeDetail(String animeId) {
    go(AppRoutes.animeDetailPath(animeId));
  }

  /// Navigate to anime AI page.
  void goToAnimeAi(String animeId) {
    go(AppRoutes.animeAiPath(animeId));
  }

  /// Navigate to favorites page.
  void goToFavorites() {
    go(AppRoutes.favorites);
  }

  /// Navigate to login page.
  void goToLogin() {
    go(AppRoutes.login);
  }

  /// Navigate to register page.
  void goToRegister() {
    go(AppRoutes.register);
  }
}
