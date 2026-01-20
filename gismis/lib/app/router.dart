import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/ai_assistant/ui/ai_assistant_page.dart';
import '../features/anime_detail/ui/anime_detail_page.dart';
import '../features/auth/domain/auth_providers.dart';
import '../features/auth/ui/login_page.dart';
import '../features/auth/ui/register_page.dart';
import '../features/favorites/ui/favorites_page.dart';
import '../features/home/ui/home_page.dart';
import '../features/profile/ui/profile_page.dart';
import '../features/schedule/ui/schedule_page.dart';
import 'main_shell.dart';
import 'theme/app_animations.dart';

/// Route paths for the application.
abstract final class AppRoutes {
  static const home = '/';
  static const schedule = '/schedule';
  static const ai = '/ai';
  static const profile = '/profile';
  static const animeDetail = '/anime/:id';
  static const animeAi = '/anime/:id/ai';
  static const login = '/login';
  static const register = '/register';
  static const favorites = '/favorites';

  /// Generate anime detail path with ID.
  static String animeDetailPath(String id) => '/anime/$id';

  /// Generate anime AI path with ID.
  static String animeAiPath(String id) => '/anime/$id/ai';
}

/// Provider for the GoRouter instance.
final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
    redirect: (context, state) {
      final isAuthenticated = authService.isAuthenticated;
      final isAuthRoute =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      // Routes that require authentication
      final protectedRoutes = [AppRoutes.favorites, AppRoutes.profile];

      final isProtectedRoute = protectedRoutes.any(
        (route) => state.matchedLocation.startsWith(route),
      );

      // If trying to access protected route without auth, redirect to login
      if (isProtectedRoute && !isAuthenticated) {
        return '${AppRoutes.login}?redirect=${state.matchedLocation}';
      }

      // If authenticated and on auth route, redirect to home
      if (isAuthenticated && isAuthRoute) {
        final redirect = state.uri.queryParameters['redirect'];
        return redirect ?? AppRoutes.home;
      }

      return null;
    },
    routes: [
      // Shell route for bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) =>
                _buildPage(key: state.pageKey, child: const HomePage()),
          ),
          GoRoute(
            path: AppRoutes.schedule,
            pageBuilder: (context, state) =>
                _buildPage(key: state.pageKey, child: const SchedulePage()),
          ),
          GoRoute(
            path: AppRoutes.ai,
            pageBuilder: (context, state) =>
                _buildPage(key: state.pageKey, child: const AiAssistantPage()),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) =>
                _buildPage(key: state.pageKey, child: const ProfilePage()),
          ),
        ],
      ),
      // Anime detail route (outside shell for full-screen experience)
      GoRoute(
        path: AppRoutes.animeDetail,
        pageBuilder: (context, state) {
          final animeId = state.pathParameters['id']!;
          return _buildPage(
            key: state.pageKey,
            child: AnimeDetailPage(animeId: animeId),
            isDetailPage: true,
          );
        },
      ),
      // Anime AI route (outside shell)
      GoRoute(
        path: AppRoutes.animeAi,
        pageBuilder: (context, state) {
          final animeId = state.pathParameters['id']!;
          return _buildPage(
            key: state.pageKey,
            child: AiAssistantPage(animeId: animeId),
            isDetailPage: true,
          );
        },
      ),
      // Auth routes (outside shell)
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _buildPage(
          key: state.pageKey,
          child: LoginPage(
            onLoginSuccess: () => context.go(AppRoutes.home),
            onNavigateToRegister: () => context.go(AppRoutes.register),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) => _buildPage(
          key: state.pageKey,
          child: RegisterPage(
            onRegisterSuccess: () => context.go(AppRoutes.home),
            onNavigateToLogin: () => context.go(AppRoutes.login),
          ),
        ),
      ),
      // Favorites route (outside shell for full-screen)
      GoRoute(
        path: AppRoutes.favorites,
        pageBuilder: (context, state) =>
            _buildPage(key: state.pageKey, child: const FavoritesPage()),
      ),
    ],
    errorPageBuilder: (context, state) => _buildPage(
      key: state.pageKey,
      child: _ErrorPage(error: state.error),
    ),
  );
});

/// Build a custom page with gentle transition animation.
/// Uses fade + subtle slide for a calm, relaxed feel.
/// Hero animations are handled automatically by Flutter.
CustomTransitionPage<void> _buildPage({
  required LocalKey key,
  required Widget child,
  bool isDetailPage = false,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: isDetailPage
        ? AppAnimations.heroDuration
        : AppAnimations.pageTransition,
    reverseTransitionDuration: isDetailPage
        ? AppAnimations.heroDuration
        : AppAnimations.pageTransition,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Use different transitions for detail pages vs tab pages
      if (isDetailPage) {
        // For detail pages: fade only to let Hero shine
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: AppAnimations.heroCurve,
        );
        return FadeTransition(opacity: fadeAnimation, child: child);
      }

      // For tab pages: gentle fade + slight slide
      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: AppAnimations.enterCurve,
      );

      final slideAnimation = Tween<Offset>(
        begin: const Offset(0.02, 0),
        end: Offset.zero,
      ).animate(fadeAnimation);

      return FadeTransition(
        opacity: fadeAnimation,
        child: SlideTransition(position: slideAnimation, child: child),
      );
    },
  );
}

/// Error page for navigation errors.
class _ErrorPage extends StatelessWidget {
  const _ErrorPage({this.error});
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (error != null)
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A [ChangeNotifier] that listens to a stream and notifies listeners
/// when the stream emits a new value. Used for GoRouter refresh.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _stream = stream.asBroadcastStream();
    final subscription = _stream.listen((_) => notifyListeners());
    _unsubscribe = subscription.cancel;
    notifyListeners();
  }
  late final Stream<dynamic> _stream;
  late final void Function() _unsubscribe;

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}
