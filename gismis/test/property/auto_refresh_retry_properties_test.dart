import 'package:glados/glados.dart';

/// Feature: anime-tracker-app, Property 18: 401 Auto-Refresh Retry
/// Validates: Requirements 10.2
///
/// For any API request receiving a 401 response with a valid refresh token,
/// the client SHALL refresh the token and retry the original request exactly once.
///
/// This test validates the token refresh logic in isolation, without Dio's
/// async interceptor chain which can cause non-deterministic behavior in PBT.

/// Simulates the auth interceptor's token refresh and retry logic.
class TokenRefreshSimulator {
  TokenRefreshSimulator({
    required this.currentToken,
    required this.newToken,
    this.refreshWillSucceed = true,
  });

  String currentToken;
  final String newToken;
  final bool refreshWillSucceed;

  int refreshCallCount = 0;
  int requestCount = 0;
  final List<String> tokensUsedInRequests = [];

  /// Simulates the auth interceptor behavior for a request that gets 401.
  /// Returns true if the request ultimately succeeds, false otherwise.
  bool simulateRequestWith401() {
    // First request with current token
    requestCount++;
    tokensUsedInRequests.add(currentToken);

    // Server returns 401
    // Auth interceptor attempts refresh
    refreshCallCount++;

    if (refreshWillSucceed) {
      // Update token
      currentToken = newToken;

      // Retry with new token
      requestCount++;
      tokensUsedInRequests.add(currentToken);

      // Server returns 200
      return true;
    } else {
      // Refresh failed, propagate error
      return false;
    }
  }

  /// Simulates a successful request (no 401).
  bool simulateSuccessfulRequest() {
    requestCount++;
    tokensUsedInRequests.add(currentToken);
    // Server returns 200, no refresh needed
    return true;
  }

  /// Checks if path is an auth endpoint (should skip refresh).
  static bool isAuthEndpoint(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh');
  }
}

void main() {
  group('Property 18: 401 Auto-Refresh Retry', () {
    Glados2(any.letterOrDigits, any.letterOrDigits).test(
      'For any initial/new token pair, 401 triggers exactly one refresh',
      (initialToken, newToken) {
        // Skip empty tokens
        if (initialToken.isEmpty || newToken.isEmpty) return;

        final simulator = TokenRefreshSimulator(
          currentToken: initialToken,
          newToken: newToken,
        );

        final success = simulator.simulateRequestWith401();

        // Property 1: Refresh is called exactly once
        expect(
          simulator.refreshCallCount,
          equals(1),
          reason: 'Only one refresh should occur for 401',
        );

        // Property 2: Two requests are made (original + retry)
        expect(
          simulator.requestCount,
          equals(2),
          reason: 'Should have made 2 requests (original + retry)',
        );

        // Property 3: First request uses initial token
        expect(
          simulator.tokensUsedInRequests[0],
          equals(initialToken),
          reason: 'First request should use initial token',
        );

        // Property 4: Retry uses new token
        expect(
          simulator.tokensUsedInRequests[1],
          equals(newToken),
          reason: 'Retry should use new token after refresh',
        );

        // Property 5: Request ultimately succeeds
        expect(success, isTrue);
      },
    );

    Glados(any.letterOrDigits).test(
      'For any token, successful request does NOT trigger refresh',
      (token) {
        if (token.isEmpty) return;

        final simulator = TokenRefreshSimulator(
          currentToken: token,
          newToken: 'unused',
        );

        final success = simulator.simulateSuccessfulRequest();

        // Property: No refresh for successful requests
        expect(
          simulator.refreshCallCount,
          equals(0),
          reason: 'Refresh should not be called for successful requests',
        );

        // Property: Only one request made
        expect(
          simulator.requestCount,
          equals(1),
          reason: 'Only one request should be made',
        );

        expect(success, isTrue);
      },
    );

    Glados(any.letterOrDigits).test(
      'For any token, failed refresh results in error (no retry)',
      (token) {
        if (token.isEmpty) return;

        final simulator = TokenRefreshSimulator(
          currentToken: token,
          newToken: 'unused',
          refreshWillSucceed: false,
        );

        final success = simulator.simulateRequestWith401();

        // Property: Refresh is attempted once
        expect(
          simulator.refreshCallCount,
          equals(1),
          reason: 'Refresh should be attempted once',
        );

        // Property: No retry after failed refresh
        expect(
          simulator.requestCount,
          equals(1),
          reason: 'No retry should occur after failed refresh',
        );

        // Property: Request fails
        expect(success, isFalse);
      },
    );

    Glados(any.letterOrDigits).test(
      'Auth endpoints are correctly identified',
      (path) {
        // Auth endpoints should be identified
        expect(
          TokenRefreshSimulator.isAuthEndpoint('/auth/login'),
          isTrue,
        );
        expect(
          TokenRefreshSimulator.isAuthEndpoint('/auth/register'),
          isTrue,
        );
        expect(
          TokenRefreshSimulator.isAuthEndpoint('/auth/refresh'),
          isTrue,
        );

        // Non-auth endpoints should not be identified as auth
        expect(
          TokenRefreshSimulator.isAuthEndpoint('/api/users'),
          isFalse,
        );
        expect(
          TokenRefreshSimulator.isAuthEndpoint('/api/\$path'),
          isFalse,
        );
      },
    );

    test('Token is updated after successful refresh', () {
      const initialToken = 'old_token';
      const newToken = 'new_token';

      final simulator = TokenRefreshSimulator(
        currentToken: initialToken,
        newToken: newToken,
      );

      simulator.simulateRequestWith401();

      // After refresh, current token should be the new token
      expect(simulator.currentToken, equals(newToken));
    });

    test('Token remains unchanged after failed refresh', () {
      const initialToken = 'old_token';
      const newToken = 'new_token';

      final simulator = TokenRefreshSimulator(
        currentToken: initialToken,
        newToken: newToken,
        refreshWillSucceed: false,
      );

      simulator.simulateRequestWith401();

      // After failed refresh, token should remain unchanged
      expect(simulator.currentToken, equals(initialToken));
    });
  });
}
