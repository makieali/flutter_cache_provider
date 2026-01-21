import 'package:flutter_cache_provider/src/eviction_policy.dart';

/// Configuration options for the cache.
///
/// Example:
/// ```dart
/// final config = CacheConfig(
///   defaultTTL: Duration(minutes: 30),
///   maxEntries: 1000,
///   enableAutoTrim: true,
///   autoTrimInterval: Duration(minutes: 5),
///   evictionPolicy: EvictionPolicyType.lru,
///   recordStats: true,
/// );
/// ```
class CacheConfig {
  /// Creates a cache configuration with the specified options.
  const CacheConfig({
    this.defaultTTL = const Duration(hours: 1),
    this.maxEntries,
    this.enableAutoTrim = false,
    this.autoTrimInterval = const Duration(minutes: 5),
    this.onEvicted,
    this.evictionPolicy = EvictionPolicyType.lru,
    this.recordStats = false,
    this.staleWhileRevalidate = false,
    this.staleTime,
    this.enableEventStream = false,
  });

  /// Creates a configuration with no TTL (permanent cache).
  const CacheConfig.permanent()
      : defaultTTL = null,
        maxEntries = null,
        enableAutoTrim = false,
        autoTrimInterval = const Duration(minutes: 5),
        onEvicted = null,
        evictionPolicy = EvictionPolicyType.lru,
        recordStats = false,
        staleWhileRevalidate = false,
        staleTime = null,
        enableEventStream = false;

  /// Creates a short-lived cache configuration (5 minutes default TTL).
  const CacheConfig.shortLived()
      : defaultTTL = const Duration(minutes: 5),
        maxEntries = null,
        enableAutoTrim = true,
        autoTrimInterval = const Duration(minutes: 1),
        onEvicted = null,
        evictionPolicy = EvictionPolicyType.lru,
        recordStats = false,
        staleWhileRevalidate = false,
        staleTime = null,
        enableEventStream = false;

  /// Creates a long-lived cache configuration (24 hours default TTL).
  const CacheConfig.longLived()
      : defaultTTL = const Duration(hours: 24),
        maxEntries = null,
        enableAutoTrim = true,
        autoTrimInterval = const Duration(hours: 1),
        onEvicted = null,
        evictionPolicy = EvictionPolicyType.lru,
        recordStats = false,
        staleWhileRevalidate = false,
        staleTime = null,
        enableEventStream = false;

  /// Creates a high-performance configuration with metrics enabled.
  const CacheConfig.highPerformance()
      : defaultTTL = const Duration(minutes: 15),
        maxEntries = 10000,
        enableAutoTrim = true,
        autoTrimInterval = const Duration(minutes: 2),
        onEvicted = null,
        evictionPolicy = EvictionPolicyType.lfu,
        recordStats = true,
        staleWhileRevalidate = false,
        staleTime = null,
        enableEventStream = false;

  /// Default time-to-live for cache entries.
  ///
  /// If null, entries do not expire by default.
  final Duration? defaultTTL;

  /// Maximum number of entries to keep in the cache.
  ///
  /// If null, no limit is enforced.
  /// When exceeded, oldest entries are evicted first (LRU-like behavior).
  final int? maxEntries;

  /// Whether to automatically trim expired entries periodically.
  final bool enableAutoTrim;

  /// Interval for automatic cache trimming.
  ///
  /// Only used if [enableAutoTrim] is true.
  final Duration autoTrimInterval;

  /// Callback invoked when an entry is evicted from the cache.
  ///
  /// The callback receives the key and value of the evicted entry.
  final void Function(String key, dynamic value)? onEvicted;

  /// The eviction policy to use when cache is full.
  ///
  /// Defaults to [EvictionPolicyType.lru] (Least Recently Used).
  final EvictionPolicyType evictionPolicy;

  /// Whether to record cache statistics (hits, misses, latency).
  ///
  /// Enable this for monitoring and debugging. Has minimal performance impact.
  final bool recordStats;

  /// Whether to enable stale-while-revalidate pattern.
  ///
  /// When enabled, stale entries are returned immediately while
  /// a background refresh is triggered.
  final bool staleWhileRevalidate;

  /// Duration after which an entry is considered "stale" but still usable.
  ///
  /// Only used when [staleWhileRevalidate] is true.
  /// If null, defaults to half of [defaultTTL].
  final Duration? staleTime;

  /// Whether to emit events on the cache event stream.
  ///
  /// Enable this to subscribe to cache changes reactively.
  final bool enableEventStream;

  /// Creates a copy of this configuration with updated values.
  CacheConfig copyWith({
    Duration? defaultTTL,
    int? maxEntries,
    bool? enableAutoTrim,
    Duration? autoTrimInterval,
    void Function(String key, dynamic value)? onEvicted,
    EvictionPolicyType? evictionPolicy,
    bool? recordStats,
    bool? staleWhileRevalidate,
    Duration? staleTime,
    bool? enableEventStream,
  }) {
    return CacheConfig(
      defaultTTL: defaultTTL ?? this.defaultTTL,
      maxEntries: maxEntries ?? this.maxEntries,
      enableAutoTrim: enableAutoTrim ?? this.enableAutoTrim,
      autoTrimInterval: autoTrimInterval ?? this.autoTrimInterval,
      onEvicted: onEvicted ?? this.onEvicted,
      evictionPolicy: evictionPolicy ?? this.evictionPolicy,
      recordStats: recordStats ?? this.recordStats,
      staleWhileRevalidate: staleWhileRevalidate ?? this.staleWhileRevalidate,
      staleTime: staleTime ?? this.staleTime,
      enableEventStream: enableEventStream ?? this.enableEventStream,
    );
  }

  @override
  String toString() {
    return 'CacheConfig('
        'defaultTTL: $defaultTTL, '
        'maxEntries: $maxEntries, '
        'enableAutoTrim: $enableAutoTrim, '
        'autoTrimInterval: $autoTrimInterval, '
        'evictionPolicy: $evictionPolicy, '
        'recordStats: $recordStats)';
  }
}
