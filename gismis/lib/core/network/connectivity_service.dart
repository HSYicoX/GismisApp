import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents the current network connectivity status.
enum ConnectivityStatus {
  /// Device is connected to the internet.
  connected,

  /// Device is offline or has no internet access.
  disconnected,

  /// Connectivity status is unknown (initial state).
  unknown,
}

/// Service for monitoring network connectivity status.
///
/// This service periodically checks internet connectivity by attempting
/// to resolve a DNS lookup. It exposes a stream of connectivity changes
/// that can be consumed by providers and UI components.
///
/// Requirements: 9.5, 11.7
/// - Gracefully degrade to cached data when network is unavailable
/// - Monitor network connectivity
class ConnectivityService {
  ConnectivityService({
    this.checkInterval = const Duration(seconds: 10),
    this.checkTimeout = const Duration(seconds: 5),
  });

  /// Interval between connectivity checks.
  final Duration checkInterval;

  /// Timeout for each connectivity check.
  final Duration checkTimeout;

  final _statusController = StreamController<ConnectivityStatus>.broadcast();
  Timer? _checkTimer;
  ConnectivityStatus _currentStatus = ConnectivityStatus.unknown;
  bool _isDisposed = false;

  /// Stream of connectivity status changes.
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  /// Current connectivity status.
  ConnectivityStatus get currentStatus => _currentStatus;

  /// Whether the device is currently connected to the internet.
  bool get isConnected => _currentStatus == ConnectivityStatus.connected;

  /// Whether the device is currently offline.
  bool get isOffline => _currentStatus == ConnectivityStatus.disconnected;

  /// Start monitoring connectivity.
  ///
  /// This will immediately check connectivity and then continue
  /// checking at the specified interval.
  Future<void> startMonitoring() async {
    if (_isDisposed) return;

    // Perform initial check
    await checkConnectivity();

    // Start periodic checks
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(checkInterval, (_) => checkConnectivity());
  }

  /// Stop monitoring connectivity.
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Manually check connectivity status.
  ///
  /// Returns the current connectivity status after the check.
  Future<ConnectivityStatus> checkConnectivity() async {
    if (_isDisposed) return _currentStatus;

    try {
      // Try to resolve a well-known domain to check internet connectivity
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(checkTimeout);

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _updateStatus(ConnectivityStatus.connected);
      } else {
        _updateStatus(ConnectivityStatus.disconnected);
      }
    } on SocketException catch (_) {
      _updateStatus(ConnectivityStatus.disconnected);
    } on TimeoutException catch (_) {
      _updateStatus(ConnectivityStatus.disconnected);
    } catch (_) {
      // For any other error, assume disconnected
      _updateStatus(ConnectivityStatus.disconnected);
    }

    return _currentStatus;
  }

  void _updateStatus(ConnectivityStatus newStatus) {
    if (_isDisposed) return;

    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
    }
  }

  /// Dispose the service and release resources.
  Future<void> dispose() async {
    _isDisposed = true;
    stopMonitoring();
    await _statusController.close();
  }
}

/// Provider for the ConnectivityService singleton.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();

  // Start monitoring when the provider is created
  service.startMonitoring();

  // Dispose when the provider is disposed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Provider that exposes the current connectivity status as a stream.
final connectivityStatusProvider = StreamProvider<ConnectivityStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.statusStream;
});

/// Provider that returns whether the device is currently offline.
///
/// This is a convenience provider for UI components that need to show
/// offline indicators.
final isOfflineProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(connectivityStatusProvider);
  return statusAsync.when(
    data: (status) => status == ConnectivityStatus.disconnected,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider that returns the current connectivity status synchronously.
///
/// Returns ConnectivityStatus.unknown if the status hasn't been determined yet.
final currentConnectivityProvider = Provider<ConnectivityStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.currentStatus;
});
