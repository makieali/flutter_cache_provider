import 'dart:async';

import 'package:flutter_cache_provider/src/cache.dart';
import 'package:flutter_cache_provider/src/cache_config.dart';
import 'package:flutter_cache_provider/src/cache_entry.dart';

/// A function that loads a value for a given key.
typedef CacheLoader<K, V> = Future<V> Function(K key);

/// A cache that automatically loads values on cache misses.
///
/// Similar to Caffeine's LoadingCache in Java, this cache automatically
/// computes values when they are not present, ensuring that the computation
/// only happens once even with concurrent requests for the same key.
///
/// Example:
/// ```dart
/// final userCache = LoadingCache<String, User>(
///   loader: (id) => api.fetchUser(id),
///   config: CacheConfig(
///     defaultTTL: Duration(minutes: 30),
///     maxEntries: 1000,
///   ),
/// );
///
/// // Automatically fetches user if not cached
/// final user = await userCache.get('user_123');
/// ```
class LoadingCache<K, V> {
  /// Creates a loading cache with the specified [loader] and optional [config].
  LoadingCache({
    required this.loader,
    CacheConfig? config,
  }) : _cache = Cache(config: config);

  /// The loader function that fetches values for cache misses.
  final CacheLoader<K, V> loader;

  /// The underlying cache.
  final Cache _cache;

  /// Tracks in-flight loads to prevent duplicate requests.
  final Map<K, Future<V>> _inFlightLoads = {};

  /// Gets a value from the cache, loading it if not present.
  ///
  /// If the value is being loaded by another call, this will wait
  /// for that load to complete instead of starting a new one.
  Future<V> get(K key) async {
    final keyStr = _keyToString(key);

    // Check cache first
    final cached = _cache.get<V>(keyStr);
    if (cached != null) {
      return cached;
    }

    // Check if already loading
    if (_inFlightLoads.containsKey(key)) {
      return _inFlightLoads[key]!;
    }

    // Start loading
    final loadFuture = _load(key, keyStr);
    _inFlightLoads[key] = loadFuture;

    try {
      return await loadFuture;
    } finally {
      _inFlightLoads.remove(key);
    }
  }

  Future<V> _load(K key, String keyStr) async {
    final value = await loader(key);
    _cache.set(keyStr, value);
    return value;
  }

  /// Gets a value if present, without triggering a load.
  V? getIfPresent(K key) {
    return _cache.get<V>(_keyToString(key));
  }

  /// Gets multiple values, loading any that are missing.
  Future<Map<K, V>> getAll(Iterable<K> keys) async {
    final result = <K, V>{};
    final futures = <Future<void>>[];

    for (final key in keys) {
      final future = get(key).then((value) => result[key] = value);
      futures.add(future);
    }

    await Future.wait(futures);
    return result;
  }

  /// Puts a value directly into the cache.
  void put(K key, V value) {
    _cache.set(_keyToString(key), value);
  }

  /// Puts multiple values directly into the cache.
  void putAll(Map<K, V> entries) {
    for (final entry in entries.entries) {
      put(entry.key, entry.value);
    }
  }

  /// Invalidates (removes) a key from the cache.
  void invalidate(K key) {
    _cache.remove<V>(_keyToString(key));
  }

  /// Invalidates multiple keys from the cache.
  void invalidateAll(Iterable<K> keys) {
    for (final key in keys) {
      invalidate(key);
    }
  }

  /// Invalidates all entries in the cache.
  void invalidateAllEntries() {
    _cache.clear();
  }

  /// Refreshes a key by reloading its value.
  ///
  /// This is useful for forcing a refresh of cached data.
  Future<V> refresh(K key) async {
    invalidate(key);
    return get(key);
  }

  /// Returns the approximate number of entries in the cache.
  int get size => _cache.length;

  /// Returns true if the cache contains the specified key.
  bool containsKey(K key) {
    return _cache.containsKey(_keyToString(key));
  }

  /// Gets the cache entry for a key, if present.
  CacheEntry<V>? getEntry(K key) {
    return _cache.getEntry<V>(_keyToString(key));
  }

  /// Disposes the cache and releases resources.
  void dispose() {
    _cache.dispose();
    _inFlightLoads.clear();
  }

  String _keyToString(K key) => key.toString();
}

/// A loading cache with synchronous loader support.
///
/// Use this for cases where the loader is synchronous
/// (e.g., computing values from existing data).
class SyncLoadingCache<K, V> {
  /// Creates a sync loading cache with the specified [loader].
  SyncLoadingCache({
    required this.loader,
    CacheConfig? config,
  }) : _cache = Cache(config: config);

  /// The synchronous loader function.
  final V Function(K key) loader;

  final Cache _cache;

  /// Gets a value from the cache, loading it if not present.
  V get(K key) {
    final keyStr = key.toString();
    final cached = _cache.get<V>(keyStr);
    if (cached != null) {
      return cached;
    }

    final value = loader(key);
    _cache.set(keyStr, value);
    return value;
  }

  /// Gets a value if present, without triggering a load.
  V? getIfPresent(K key) {
    return _cache.get<V>(key.toString());
  }

  /// Puts a value directly into the cache.
  void put(K key, V value) {
    _cache.set(key.toString(), value);
  }

  /// Invalidates a key from the cache.
  void invalidate(K key) {
    _cache.remove<V>(key.toString());
  }

  /// Invalidates all entries.
  void invalidateAllEntries() {
    _cache.clear();
  }

  /// Returns the number of entries.
  int get size => _cache.length;

  /// Disposes the cache.
  void dispose() {
    _cache.dispose();
  }
}

/// Extension to create a loading cache from a regular cache.
extension LoadingCacheExtension on Cache {
  /// Wraps this cache with a loader function.
  LoadingCache<String, V> withLoader<V>(CacheLoader<String, V> loader) {
    return _WrappedLoadingCache<V>(this, loader);
  }
}

class _WrappedLoadingCache<V> extends LoadingCache<String, V> {
  _WrappedLoadingCache(this._wrappedCache, CacheLoader<String, V> loader)
      : super(loader: loader);

  final Cache _wrappedCache;

  @override
  Cache get _cache => _wrappedCache;
}
