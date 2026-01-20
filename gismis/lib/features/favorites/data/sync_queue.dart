import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Types of sync operations for favorites.
enum SyncType {
  /// Add an anime to favorites.
  addFavorite('add_favorite'),

  /// Remove an anime from favorites.
  removeFavorite('remove_favorite'),

  /// Update favorite order.
  updateOrder('update_order');

  const SyncType(this.value);
  final String value;

  static SyncType fromString(String value) {
    return SyncType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SyncType.addFavorite,
    );
  }
}

/// Represents a single sync operation to be processed.
///
/// Operations are queued when offline and processed when connectivity
/// is restored.
///
/// Requirements: 5.5 - Offline queue for pending sync operations
@immutable
class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
    this.lastError,
  });

  /// Creates a SyncOperation from JSON.
  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      type: SyncType.fromString(json['type'] as String),
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
      retryCount: json['retry_count'] as int? ?? 0,
      lastError: json['last_error'] as String?,
    );
  }

  /// Unique identifier for this operation.
  final String id;

  /// The type of sync operation.
  final SyncType type;

  /// The data payload for the operation.
  final Map<String, dynamic> data;

  /// When the operation was created.
  final DateTime timestamp;

  /// Number of times this operation has been retried.
  final int retryCount;

  /// The last error message if the operation failed.
  final String? lastError;

  /// Maximum number of retries before giving up.
  static const int maxRetries = 3;

  /// Whether this operation can be retried.
  bool get canRetry => retryCount < maxRetries;

  /// Converts to JSON for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
    };
  }

  /// Creates a copy with incremented retry count and error message.
  SyncOperation withError(String error) {
    return SyncOperation(
      id: id,
      type: type,
      data: data,
      timestamp: timestamp,
      retryCount: retryCount + 1,
      lastError: error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SyncOperation) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SyncOperation(id: $id, type: ${type.value}, '
        'retryCount: $retryCount)';
  }
}

/// Manages a queue of sync operations for offline support.
///
/// Operations are persisted to Hive storage and processed when
/// connectivity is available.
///
/// Requirements: 5.5 - Offline queue for pending sync operations
class SyncQueue {
  SyncQueue({required this.boxName});

  /// The name of the Hive box for storing operations.
  final String boxName;

  Box<String>? _box;
  bool _isInitialized = false;

  /// Initialize the sync queue storage.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _box = await Hive.openBox<String>(boxName);
    _isInitialized = true;
  }

  void _ensureInitialized() {
    if (!_isInitialized || _box == null) {
      throw StateError('SyncQueue not initialized. Call initialize() first.');
    }
  }

  /// Gets all pending operations in order.
  List<SyncOperation> get pending {
    _ensureInitialized();
    final operations = <SyncOperation>[];

    for (final key in _box!.keys) {
      final jsonString = _box!.get(key);
      if (jsonString != null) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          operations.add(SyncOperation.fromJson(json));
        } on FormatException {
          // Skip malformed entries
          debugPrint('SyncQueue: Skipping malformed entry: $key');
        }
      }
    }

    // Sort by timestamp (oldest first)
    operations.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return operations;
  }

  /// Gets the number of pending operations.
  int get pendingCount {
    _ensureInitialized();
    return _box!.length;
  }

  /// Whether there are pending operations.
  bool get hasPending => pendingCount > 0;

  /// Adds an operation to the queue.
  Future<void> enqueue(SyncOperation operation) async {
    _ensureInitialized();
    final jsonString = jsonEncode(operation.toJson());
    await _box!.put(operation.id, jsonString);
  }

  /// Removes an operation from the queue.
  Future<void> dequeue(String operationId) async {
    _ensureInitialized();
    await _box!.delete(operationId);
  }

  /// Updates an operation in the queue (e.g., after retry failure).
  Future<void> update(SyncOperation operation) async {
    _ensureInitialized();
    final jsonString = jsonEncode(operation.toJson());
    await _box!.put(operation.id, jsonString);
  }

  /// Clears all processed operations from the queue.
  Future<void> clearProcessed(List<SyncOperation> processed) async {
    _ensureInitialized();
    for (final op in processed) {
      await _box!.delete(op.id);
    }
  }

  /// Clears all operations from the queue.
  Future<void> clear() async {
    _ensureInitialized();
    await _box!.clear();
  }

  /// Gets operations that can still be retried.
  List<SyncOperation> get retryable {
    return pending.where((op) => op.canRetry).toList();
  }

  /// Gets operations that have exceeded retry limit.
  List<SyncOperation> get failed {
    return pending.where((op) => !op.canRetry).toList();
  }

  /// Removes operations that have exceeded retry limit.
  Future<void> purgeFailed() async {
    _ensureInitialized();
    final failedOps = failed;
    for (final op in failedOps) {
      await _box!.delete(op.id);
    }
  }

  /// Closes the storage box.
  Future<void> dispose() async {
    await _box?.close();
    _isInitialized = false;
  }
}
