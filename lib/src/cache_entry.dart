import 'package:flutter/foundation.dart';

/// A cache entry that holds data with an expiration time.
///
/// Each cache entry contains:
/// - The cached value of type [T]
/// - A timestamp when the entry was created
/// - An expiration time after which the entry is considered invalid
///
/// Example:
/// ```dart
/// final entry = CacheEntry<String>(
///   'cached value',
///   ttl: Duration(minutes: 30),
/// );
///
/// if (entry.isValid) {
///   print(entry.value); // Use cached value
/// }
/// ```
@immutable
class CacheEntry<T> {
  /// Creates a cache entry with the given [value] and optional [ttl].
  ///
  /// If [ttl] is not provided, the entry never expires automatically.
  /// If [timestamp] is not provided, the current time is used.
  CacheEntry(
    this.value, {
    Duration? ttl,
    DateTime? timestamp,
  })  : createdAt = timestamp ?? DateTime.now(),
        expiresAt = ttl != null
            ? (timestamp ?? DateTime.now()).add(ttl)
            : null;

  /// Creates a cache entry that never expires.
  CacheEntry.permanent(this.value)
      : createdAt = DateTime.now(),
        expiresAt = null;

  /// Creates a cache entry from a JSON map.
  ///
  /// The [fromValue] function converts the stored value back to type [T].
  factory CacheEntry.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromValue,
  ) {
    return CacheEntry<T>(
      fromValue(json['value']),
      timestamp: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      ttl: json['ttlMs'] != null
          ? Duration(milliseconds: json['ttlMs'] as int)
          : null,
    );
  }

  /// The cached value.
  final T value;

  /// When this entry was created.
  final DateTime createdAt;

  /// When this entry expires, or null if it never expires.
  final DateTime? expiresAt;

  /// Returns true if this entry has not expired.
  ///
  /// An entry is considered valid if:
  /// - It has no expiration time (permanent), or
  /// - The current time is before the expiration time
  bool get isValid {
    if (expiresAt == null) return true;
    return DateTime.now().isBefore(expiresAt!);
  }

  /// Returns true if this entry has expired.
  bool get isExpired => !isValid;

  /// The age of this cache entry.
  Duration get age => DateTime.now().difference(createdAt);

  /// Time remaining until this entry expires, or null if permanent.
  Duration? get timeToLive {
    if (expiresAt == null) return null;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Converts this entry to a JSON map.
  ///
  /// The [toValue] function converts the value to a JSON-compatible type.
  Map<String, dynamic> toJson([dynamic Function(T)? toValue]) {
    return {
      'value': toValue != null ? toValue(value) : value,
      'createdAt': createdAt.toIso8601String(),
      if (expiresAt != null)
        'ttlMs': expiresAt!.difference(createdAt).inMilliseconds,
    };
  }

  /// Creates a copy of this entry with updated fields.
  CacheEntry<T> copyWith({
    T? value,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    final newCreatedAt = createdAt ?? this.createdAt;
    final newExpiresAt = expiresAt ?? this.expiresAt;

    return CacheEntry<T>(
      value ?? this.value,
      timestamp: newCreatedAt,
      ttl: newExpiresAt?.difference(newCreatedAt),
    );
  }

  @override
  String toString() {
    return 'CacheEntry<$T>('
        'value: $value, '
        'createdAt: $createdAt, '
        'expiresAt: $expiresAt, '
        'isValid: $isValid)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CacheEntry<T> &&
        other.value == value &&
        other.createdAt == createdAt &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode => Object.hash(value, createdAt, expiresAt);
}
