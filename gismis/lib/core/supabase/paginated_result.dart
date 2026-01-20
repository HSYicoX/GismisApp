/// Paginated result container for PostgREST queries.
///
/// This class encapsulates the result of a paginated query, including
/// the items, total count, and pagination metadata.
library;

import 'package:flutter/foundation.dart';

/// A paginated result from a PostgREST query.
///
/// Contains the items for the current page along with pagination metadata
/// to support UI pagination controls and infinite scrolling.
///
/// Example:
/// ```dart
/// final result = await client.query<Anime>(
///   table: 'anime',
///   fromJson: Anime.fromJson,
///   limit: 20,
///   offset: 0,
/// );
///
/// print('Showing ${result.items.length} of ${result.total} items');
/// print('Has more: ${result.hasMore}');
/// ```
@immutable
class PaginatedResult<T> {
  /// Creates a paginated result.
  const PaginatedResult({
    required this.items,
    this.total,
    required this.offset,
    this.limit,
    required this.hasMore,
  });

  /// Creates an empty paginated result.
  const PaginatedResult.empty()
    : items = const [],
      total = 0,
      offset = 0,
      limit = null,
      hasMore = false;

  /// The items for the current page.
  final List<T> items;

  /// The total number of items across all pages.
  ///
  /// May be null if count was not requested or not available.
  final int? total;

  /// The offset (number of items skipped) for this page.
  final int offset;

  /// The limit (maximum items per page) used for this query.
  ///
  /// May be null if no limit was specified.
  final int? limit;

  /// Whether there are more items available after this page.
  final bool hasMore;

  /// The number of items in the current page.
  int get count => items.length;

  /// Whether this result is empty.
  bool get isEmpty => items.isEmpty;

  /// Whether this result is not empty.
  bool get isNotEmpty => items.isNotEmpty;

  /// The current page number (1-indexed).
  ///
  /// Returns 1 if limit is null or zero.
  int get currentPage {
    if (limit == null || limit == 0) return 1;
    return (offset ~/ limit!) + 1;
  }

  /// The total number of pages.
  ///
  /// Returns null if total is unknown or limit is null/zero.
  int? get totalPages {
    if (total == null || limit == null || limit == 0) return null;
    return (total! / limit!).ceil();
  }

  /// Creates a copy with the given fields replaced.
  PaginatedResult<T> copyWith({
    List<T>? items,
    int? total,
    int? offset,
    int? limit,
    bool? hasMore,
  }) {
    return PaginatedResult<T>(
      items: items ?? this.items,
      total: total ?? this.total,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  /// Maps the items to a new type.
  PaginatedResult<R> map<R>(R Function(T) transform) {
    return PaginatedResult<R>(
      items: items.map(transform).toList(),
      total: total,
      offset: offset,
      limit: limit,
      hasMore: hasMore,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginatedResult<T> &&
          runtimeType == other.runtimeType &&
          listEquals(items, other.items) &&
          total == other.total &&
          offset == other.offset &&
          limit == other.limit &&
          hasMore == other.hasMore;

  @override
  int get hashCode => Object.hashAll([items, total, offset, limit, hasMore]);

  @override
  String toString() =>
      'PaginatedResult<$T>('
      'count: $count, '
      'total: $total, '
      'offset: $offset, '
      'limit: $limit, '
      'hasMore: $hasMore)';
}
