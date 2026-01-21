import 'dart:async';

import 'package:flutter_cache_provider/src/cache_config.dart';
import 'package:flutter_cache_provider/src/cache_entry.dart';
import 'package:flutter_cache_provider/src/cache_event.dart';
import 'package:flutter_cache_provider/src/cache_metrics.dart';
import 'package:flutter_cache_provider/src/cache_stats.dart';
import 'package:flutter_cache_provider/src/eviction_policy.dart';

/// A flexible in-memory cache with TTL support and hierarchical keys.
///
/// The cache supports:
/// - Type-safe value storage with automatic expiration
/// - Hierarchical (nested) keys for organized data
/// - Configurable TTL per entry or global default
/// - Automatic memory management (trim expired entries)
/// - Cache statistics and monitoring
/// - Event streams for reactive updates
/// - Multiple eviction policies (LRU, LFU, FIFO)
/// - Hit/miss metrics with latency tracking
/// - Stale-while-revalidate pattern
///
/// Example:
/// ```dart
/// final cache = Cache();
///
/// // Simple key-value caching
/// cache.set('user_123', userProfile, ttl: Duration(minutes: 30));
/// final user = cache.get<UserProfile>('user_123');
///
/// // Hierarchical caching
/// cache.setPath(['users', '123', 'preferences'], prefs);
/// final prefs = cache.getPath<Preferences>(['users', '123', 'preferences']);
///
/// // Event streams (when enableEventStream: true)
/// cache.events.listen((event) {
///   print('Cache event: ${event.type} for ${event.key}');
/// });
///
/// // Metrics (when recordStats: true)
/// print('Hit ratio: ${cache.metrics.hitRatio}');
///
/// // Cleanup
/// cache.trimExpired();
/// ```
class Cache {
  /// Creates a new cache with optional [config].
  Cache({CacheConfig? config}) : config = config ?? const CacheConfig() {
    _evictionPolicy = EvictionPolicy(this.config.evictionPolicy);
    _metrics = this.config.recordStats ? CacheMetrics() : null;
    if (this.config.enableEventStream) {
      _eventController = StreamController<CacheEvent<dynamic>>.broadcast();
    }
    if (this.config.enableAutoTrim) {
      _startAutoTrim();
    }
  }

  /// The cache configuration.
  final CacheConfig config;

  /// Internal storage for cache entries.
  final Map<String, CacheEntry<dynamic>> _store = {};

  /// Timer for automatic cache trimming.
  Timer? _trimTimer;

  /// Eviction policy for managing cache capacity.
  late final EvictionPolicy _evictionPolicy;

  /// Metrics tracking (null if not enabled).
  CacheMetrics? _metrics;

  /// Event stream controller (null if not enabled).
  StreamController<CacheEvent<dynamic>>? _eventController;

  /// Tracks in-flight stale-while-revalidate operations.
  final Map<String, Future<dynamic>> _revalidating = {};

  /// The event stream for cache changes.
  ///
  /// Only emits events when [CacheConfig.enableEventStream] is true.
  Stream<CacheEvent<dynamic>> get events =>
      _eventController?.stream ?? const Stream.empty();

  /// Cache metrics (hits, misses, latency).
  ///
  /// Returns a disabled metrics instance if [CacheConfig.recordStats] is false.
  CacheMetrics get metrics => _metrics ?? CacheMetrics.disabled();

  // ============================================
  // Basic Get/Set Operations
  // ============================================

  /// Gets a value from the cache by [key].
  ///
  /// Returns null if the key doesn't exist or the entry has expired.
  /// The entry is automatically removed if expired.
  T? get<T>(String key) {
    final stopwatch = _metrics != null ? (Stopwatch()..start()) : null;

    final entry = _store[key];
    if (entry == null) {
      _metrics?.recordMiss();
      stopwatch?.stop();
      if (stopwatch != null) {
        _metrics?.recordGetLatency(stopwatch.elapsed);
      }
      return null;
    }

    if (entry.isExpired) {
      _emitEvent(CacheEvent<T>.expired(key, entry.value as T?));
      remove<dynamic>(key);
      _metrics?.recordMiss();
      stopwatch?.stop();
      if (stopwatch != null) {
        _metrics?.recordGetLatency(stopwatch.elapsed);
      }
      return null;
    }

    _evictionPolicy.onAccess(key);
    _metrics?.recordHit();
    stopwatch?.stop();
    if (stopwatch != null) {
      _metrics?.recordGetLatency(stopwatch.elapsed);
    }
    return entry.value as T;
  }

  /// Gets a value, returning stale data while revalidating in background.
  ///
  /// This implements the stale-while-revalidate pattern:
  /// - If fresh: returns the value
  /// - If stale but valid: returns stale value, triggers background refresh
  /// - If expired: calls revalidate and waits
  ///
  /// The [revalidate] function is called to fetch fresh data.
  Future<T?> getStale<T>(
    String key,
    Future<T> Function() revalidate, {
    Duration? staleTTL,
  }) async {
    final entry = _store[key];
    if (entry == null) {
      _metrics?.recordMiss();
      // No cached value, must fetch
      final value = await revalidate();
      set(key, value);
      return value;
    }

    final effectiveStaleTime = staleTTL ??
        config.staleTime ??
        (config.defaultTTL != null
            ? Duration(milliseconds: config.defaultTTL!.inMilliseconds ~/ 2)
            : const Duration(minutes: 5));

    final isStale = entry.age > effectiveStaleTime;
    final isExpired = entry.isExpired;

    if (isExpired) {
      _metrics?.recordMiss();
      // Expired, must wait for revalidation
      final value = await _revalidateEntry<T>(key, revalidate);
      return value;
    }

    if (isStale && !_revalidating.containsKey(key)) {
      // Stale but valid - trigger background revalidation
      _revalidating[key] = _revalidateEntry<T>(key, revalidate).whenComplete(
        () => _revalidating.remove(key),
      );
    }

    _evictionPolicy.onAccess(key);
    _metrics?.recordHit();
    return entry.value as T;
  }

  Future<T> _revalidateEntry<T>(
    String key,
    Future<T> Function() revalidate,
  ) async {
    final value = await revalidate();
    set(key, value);
    return value;
  }

  /// Gets a value from the cache, returning [defaultValue] if not found.
  T getOr<T>(String key, T defaultValue) {
    return get<T>(key) ?? defaultValue;
  }

  /// Gets a value from the cache, computing it if not present.
  ///
  /// If the key exists and is valid, returns the cached value.
  /// Otherwise, calls [compute] to generate the value and caches it.
  T getOrSet<T>(
    String key,
    T Function() compute, {
    Duration? ttl,
  }) {
    final existing = get<T>(key);
    if (existing != null) return existing;

    final value = compute();
    set(key, value, ttl: ttl);
    return value;
  }

  /// Asynchronous version of [getOrSet].
  Future<T> getOrSetAsync<T>(
    String key,
    Future<T> Function() compute, {
    Duration? ttl,
  }) async {
    final existing = get<T>(key);
    if (existing != null) return existing;

    final value = await compute();
    set(key, value, ttl: ttl);
    return value;
  }

  /// Sets a value in the cache with optional [ttl].
  ///
  /// If [ttl] is not provided, uses the default TTL from config.
  void set<T>(String key, T value, {Duration? ttl}) {
    final effectiveTTL = ttl ?? config.defaultTTL;
    final existingEntry = _store[key];
    final isUpdate = existingEntry != null;

    _store[key] = CacheEntry<T>(value, ttl: effectiveTTL);
    _evictionPolicy.onAdd(key);
    _enforceMaxEntries();

    if (isUpdate) {
      _emitEvent(CacheEvent<T>.updated(key, value, existingEntry.value as T?));
    } else {
      _emitEvent(CacheEvent<T>.created(key, value));
    }
  }

  /// Sets a permanent value that never expires.
  void setPermanent<T>(String key, T value) {
    final existingEntry = _store[key];
    final isUpdate = existingEntry != null;

    _store[key] = CacheEntry<T>.permanent(value);
    _evictionPolicy.onAdd(key);
    _enforceMaxEntries();

    if (isUpdate) {
      _emitEvent(CacheEvent<T>.updated(key, value, existingEntry.value as T?));
    } else {
      _emitEvent(CacheEvent<T>.created(key, value));
    }
  }

  /// Checks if a key exists and is valid in the cache.
  bool containsKey(String key) {
    final entry = _store[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      remove<dynamic>(key);
      return false;
    }
    return true;
  }

  /// Removes an entry from the cache.
  ///
  /// Returns the removed value, or null if not found.
  T? remove<T>(String key) {
    final entry = _store.remove(key);
    _evictionPolicy.onRemove(key);

    if (entry != null) {
      config.onEvicted?.call(key, entry.value);
      _emitEvent(CacheEvent<T>.removed(key, entry.value as T?));
      return entry.value as T;
    }
    return null;
  }

  // ============================================
  // Hierarchical (Path-based) Operations
  // ============================================

  /// The separator used for path-based keys.
  static const String pathSeparator = '::';

  /// Converts a path list to a cache key.
  String _pathToKey(List<String> path) => path.join(pathSeparator);

  /// Gets a value using a hierarchical path.
  ///
  /// Example:
  /// ```dart
  /// cache.getPath<List<Chapter>>(['courses', 'math', 'chapters']);
  /// ```
  T? getPath<T>(List<String> path) {
    if (path.isEmpty) return null;
    return get<T>(_pathToKey(path));
  }

  /// Sets a value using a hierarchical path.
  ///
  /// Example:
  /// ```dart
  /// cache.setPath(['courses', 'math', 'chapters'], chapters);
  /// ```
  void setPath<T>(List<String> path, T value, {Duration? ttl}) {
    if (path.isEmpty) return;
    set(_pathToKey(path), value, ttl: ttl);
  }

  /// Checks if a path exists in the cache.
  bool containsPath(List<String> path) {
    if (path.isEmpty) return false;
    return containsKey(_pathToKey(path));
  }

  /// Removes a value at the given path.
  T? removePath<T>(List<String> path) {
    if (path.isEmpty) return null;
    return remove<T>(_pathToKey(path));
  }

  /// Gets all keys that match a path prefix.
  ///
  /// Example:
  /// ```dart
  /// // Get all keys under 'courses::math'
  /// final keys = cache.getKeysWithPrefix(['courses', 'math']);
  /// ```
  List<String> getKeysWithPrefix(List<String> pathPrefix) {
    if (pathPrefix.isEmpty) return keys;

    final prefix = _pathToKey(pathPrefix);
    return _store.keys
        .where((key) => key.startsWith(prefix))
        .where(containsKey) // Filter out expired
        .toList();
  }

  /// Removes all entries that match a path prefix.
  ///
  /// Returns the number of entries removed.
  int removeWithPrefix(List<String> pathPrefix) {
    if (pathPrefix.isEmpty) {
      final count = _store.length;
      clear();
      return count;
    }

    final prefix = _pathToKey(pathPrefix);
    final keysToRemove = _store.keys
        .where((key) => key.startsWith(prefix))
        .toList();

    for (final key in keysToRemove) {
      remove<dynamic>(key);
    }

    return keysToRemove.length;
  }

  // ============================================
  // Bulk Operations
  // ============================================

  /// Gets multiple values by keys.
  Map<String, T> getAll<T>(List<String> keys) {
    final result = <String, T>{};
    for (final key in keys) {
      final value = get<T>(key);
      if (value != null) {
        result[key] = value;
      }
    }
    return result;
  }

  /// Sets multiple values at once.
  void setAll<T>(Map<String, T> entries, {Duration? ttl}) {
    for (final entry in entries.entries) {
      set(entry.key, entry.value, ttl: ttl);
    }
  }

  /// Removes multiple entries by keys.
  void removeAll(List<String> keys) {
    for (final key in keys) {
      remove<dynamic>(key);
    }
  }

  // ============================================
  // Cache Management
  // ============================================

  /// All valid keys in the cache.
  List<String> get keys {
    trimExpired(); // Clean up first
    return _store.keys.toList();
  }

  /// The number of valid entries in the cache.
  int get length {
    trimExpired();
    return _store.length;
  }

  /// Whether the cache is empty.
  bool get isEmpty => length == 0;

  /// Whether the cache has any entries.
  bool get isNotEmpty => !isEmpty;

  /// Removes all expired entries from the cache.
  ///
  /// Returns the number of entries removed.
  int trimExpired() {
    final expiredKeys = <String>[];

    for (final entry in _store.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      remove<dynamic>(key);
    }

    return expiredKeys.length;
  }

  /// Clears all entries from the cache.
  ///
  /// Optionally preserves entries with keys matching [preserve].
  void clear({Set<String>? preserve}) {
    if (preserve == null || preserve.isEmpty) {
      for (final entry in _store.entries) {
        config.onEvicted?.call(entry.key, entry.value.value);
      }
      _store.clear();
      _evictionPolicy.clear();
      _emitEvent(CacheEvent<dynamic>.cleared());
      return;
    }

    final keysToRemove = _store.keys
        .where((key) => !preserve.contains(key))
        .toList();

    for (final key in keysToRemove) {
      remove<dynamic>(key);
    }
  }

  /// Clears entries matching a predicate.
  void clearWhere(bool Function(String key, dynamic value) predicate) {
    final keysToRemove = <String>[];

    for (final entry in _store.entries) {
      if (entry.value.isValid && predicate(entry.key, entry.value.value)) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      remove<dynamic>(key);
    }
  }

  // ============================================
  // Entry Information
  // ============================================

  /// Gets the cache entry metadata for a key.
  CacheEntry<T>? getEntry<T>(String key) {
    final entry = _store[key];
    if (entry == null || entry.isExpired) return null;
    return entry as CacheEntry<T>;
  }

  /// Gets the remaining TTL for an entry.
  Duration? getTimeToLive(String key) {
    final entry = _store[key];
    if (entry == null || entry.isExpired) return null;
    return entry.timeToLive;
  }

  /// Gets the age of an entry.
  Duration? getAge(String key) {
    final entry = _store[key];
    if (entry == null || entry.isExpired) return null;
    return entry.age;
  }

  /// Extends the TTL of an existing entry.
  ///
  /// Returns true if the entry was found and extended.
  bool extendTTL(String key, Duration additionalTime) {
    final entry = _store[key];
    if (entry == null || entry.isExpired) return false;

    final newExpiry = entry.expiresAt?.add(additionalTime) ??
        DateTime.now().add(additionalTime);

    _store[key] = entry.copyWith(expiresAt: newExpiry);
    return true;
  }

  /// Refreshes an entry, resetting its TTL to the original duration.
  ///
  /// Returns true if the entry was found and refreshed.
  bool refresh(String key, {Duration? ttl}) {
    final entry = _store[key];
    if (entry == null || entry.isExpired) return false;

    final effectiveTTL = ttl ?? config.defaultTTL;
    _store[key] = CacheEntry(
      entry.value,
      ttl: effectiveTTL,
    );

    _evictionPolicy.onAccess(key);
    return true;
  }

  // ============================================
  // Statistics
  // ============================================

  /// Gets statistics about the cache.
  CacheStats getStats() {
    var validCount = 0;
    var expiredCount = 0;
    var permanentCount = 0;
    var totalAge = Duration.zero;

    for (final entry in _store.entries) {
      if (entry.value.isExpired) {
        expiredCount++;
      } else {
        validCount++;
        totalAge += entry.value.age;
        if (entry.value.expiresAt == null) {
          permanentCount++;
        }
      }
    }

    // Find oldest and newest entries by creation time
    String? oldestKey;
    String? newestKey;
    DateTime? oldestTime;
    DateTime? newestTime;

    for (final entry in _store.entries) {
      if (!entry.value.isExpired) {
        if (oldestTime == null || entry.value.createdAt.isBefore(oldestTime)) {
          oldestTime = entry.value.createdAt;
          oldestKey = entry.key;
        }
        if (newestTime == null || entry.value.createdAt.isAfter(newestTime)) {
          newestTime = entry.value.createdAt;
          newestKey = entry.key;
        }
      }
    }

    return CacheStats(
      totalEntries: _store.length,
      validEntries: validCount,
      expiredEntries: expiredCount,
      permanentEntries: permanentCount,
      averageAge: validCount > 0
          ? Duration(microseconds: totalAge.inMicroseconds ~/ validCount)
          : Duration.zero,
      oldestKey: oldestKey,
      newestKey: newestKey,
    );
  }

  // ============================================
  // Private Methods
  // ============================================

  void _emitEvent(CacheEvent<dynamic> event) {
    if (_eventController != null && !_eventController!.isClosed) {
      _eventController!.add(event);
    }
  }

  void _enforceMaxEntries() {
    final maxEntries = config.maxEntries;
    if (maxEntries == null) return;

    while (_store.length > maxEntries) {
      final candidate = _evictionPolicy.getEvictionCandidate();
      if (candidate == null) break;

      final entry = _store.remove(candidate);
      _evictionPolicy.onRemove(candidate);

      if (entry != null) {
        _metrics?.recordEviction();
        config.onEvicted?.call(candidate, entry.value);
        _emitEvent(CacheEvent<dynamic>.evicted(candidate, entry.value));
      }
    }
  }

  void _startAutoTrim() {
    _trimTimer?.cancel();
    _trimTimer = Timer.periodic(config.autoTrimInterval, (_) {
      trimExpired();
    });
  }

  // ============================================
  // Cache Warming
  // ============================================

  /// Warms up the cache with the given entries.
  ///
  /// Useful for pre-loading frequently accessed data.
  void warmUp<T>(Map<String, T> entries, {Duration? ttl}) {
    for (final entry in entries.entries) {
      set(entry.key, entry.value, ttl: ttl);
    }
  }

  /// Warms up the cache by loading values asynchronously.
  ///
  /// The [loader] function is called for each key to fetch the value.
  Future<void> warmUpAsync<T>(
    List<String> keys,
    Future<T> Function(String key) loader, {
    Duration? ttl,
  }) async {
    final futures = <Future<void>>[];

    for (final key in keys) {
      futures.add(
        loader(key).then((value) => set(key, value, ttl: ttl)),
      );
    }

    await Future.wait(futures);
  }

  /// Disposes the cache and releases resources.
  void dispose() {
    _trimTimer?.cancel();
    _trimTimer = null;
    _eventController?.close();
    _revalidating.clear();
    clear();
  }
}
