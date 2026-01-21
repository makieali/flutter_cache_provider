import 'package:flutter/foundation.dart';

/// Types of cache events that can be emitted.
enum CacheEventType {
  /// A new entry was created in the cache.
  created,

  /// An existing entry was updated with a new value.
  updated,

  /// An entry was explicitly removed from the cache.
  removed,

  /// An entry expired due to TTL.
  expired,

  /// An entry was evicted due to capacity limits.
  evicted,

  /// The cache was cleared.
  cleared,
}

/// Represents an event that occurred in the cache.
///
/// Cache events can be subscribed to for reactive updates:
///
/// ```dart
/// cache.events.listen((event) {
///   switch (event.type) {
///     case CacheEventType.created:
///       print('New entry: ${event.key}');
///       break;
///     case CacheEventType.expired:
///       analytics.trackExpiry(event.key);
///       break;
///     // ...
///   }
/// });
/// ```
@immutable
class CacheEvent<T> {
  /// Creates a cache event.
  const CacheEvent({
    required this.type,
    required this.key,
    this.value,
    this.previousValue,
    this.timestamp,
  });

  /// Creates a 'created' event.
  factory CacheEvent.created(String key, T value) {
    return CacheEvent<T>(
      type: CacheEventType.created,
      key: key,
      value: value,
      timestamp: DateTime.now(),
    );
  }

  /// Creates an 'updated' event.
  factory CacheEvent.updated(String key, T value, T? previousValue) {
    return CacheEvent<T>(
      type: CacheEventType.updated,
      key: key,
      value: value,
      previousValue: previousValue,
      timestamp: DateTime.now(),
    );
  }

  /// Creates a 'removed' event.
  factory CacheEvent.removed(String key, T? value) {
    return CacheEvent<T>(
      type: CacheEventType.removed,
      key: key,
      value: value,
      timestamp: DateTime.now(),
    );
  }

  /// Creates an 'expired' event.
  factory CacheEvent.expired(String key, T? value) {
    return CacheEvent<T>(
      type: CacheEventType.expired,
      key: key,
      value: value,
      timestamp: DateTime.now(),
    );
  }

  /// Creates an 'evicted' event.
  factory CacheEvent.evicted(String key, T? value) {
    return CacheEvent<T>(
      type: CacheEventType.evicted,
      key: key,
      value: value,
      timestamp: DateTime.now(),
    );
  }

  /// Creates a 'cleared' event.
  factory CacheEvent.cleared() {
    return CacheEvent<T>(
      type: CacheEventType.cleared,
      key: '',
      timestamp: DateTime.now(),
    );
  }

  /// The type of event that occurred.
  final CacheEventType type;

  /// The key associated with this event.
  ///
  /// Empty string for 'cleared' events.
  final String key;

  /// The value associated with the event.
  ///
  /// For 'created' and 'updated': the new value.
  /// For 'removed', 'expired', 'evicted': the removed value.
  /// May be null if the value was not captured.
  final T? value;

  /// The previous value for 'updated' events.
  final T? previousValue;

  /// When this event occurred.
  final DateTime? timestamp;

  /// Whether this event represents an entry being added.
  bool get isAddition => type == CacheEventType.created;

  /// Whether this event represents an entry being modified.
  bool get isModification => type == CacheEventType.updated;

  /// Whether this event represents an entry being removed.
  bool get isRemoval =>
      type == CacheEventType.removed ||
      type == CacheEventType.expired ||
      type == CacheEventType.evicted;

  /// Creates a copy of this event with different type parameters.
  CacheEvent<R> cast<R>() {
    return CacheEvent<R>(
      type: type,
      key: key,
      value: value as R?,
      previousValue: previousValue as R?,
      timestamp: timestamp,
    );
  }

  /// Converts this event to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'key': key,
      'timestamp': timestamp?.toIso8601String(),
      'hasValue': value != null,
      'hasPreviousValue': previousValue != null,
    };
  }

  @override
  String toString() {
    return 'CacheEvent(type: ${type.name}, key: $key, '
        'timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CacheEvent<T> &&
        other.type == type &&
        other.key == key &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(type, key, timestamp);
}

/// Filter function for cache events.
typedef CacheEventFilter = bool Function(CacheEvent<dynamic> event);

/// Extension methods for filtering cache event streams.
extension CacheEventStreamExtensions on Stream<CacheEvent<dynamic>> {
  /// Filters events by type.
  Stream<CacheEvent<dynamic>> whereType(CacheEventType type) {
    return where((event) => event.type == type);
  }

  /// Filters events by multiple types.
  Stream<CacheEvent<dynamic>> whereTypes(Set<CacheEventType> types) {
    return where((event) => types.contains(event.type));
  }

  /// Filters events by key.
  Stream<CacheEvent<dynamic>> whereKey(String key) {
    return where((event) => event.key == key);
  }

  /// Filters events by key prefix.
  Stream<CacheEvent<dynamic>> whereKeyPrefix(String prefix) {
    return where((event) => event.key.startsWith(prefix));
  }

  /// Filters to only addition events (created).
  Stream<CacheEvent<dynamic>> get additions {
    return where((event) => event.isAddition);
  }

  /// Filters to only removal events (removed, expired, evicted).
  Stream<CacheEvent<dynamic>> get removals {
    return where((event) => event.isRemoval);
  }

  /// Filters to only expiration events.
  Stream<CacheEvent<dynamic>> get expirations {
    return whereType(CacheEventType.expired);
  }

  /// Filters to only eviction events.
  Stream<CacheEvent<dynamic>> get evictions {
    return whereType(CacheEventType.evicted);
  }
}
