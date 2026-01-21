import 'package:flutter_cache_provider/src/cache_config.dart';
import 'package:flutter_cache_provider/src/eviction_policy.dart';
import 'package:flutter_cache_provider/src/loading_cache.dart';

/// Builder for creating configured caches with a fluent API.
///
/// Provides a clean, chainable interface for cache configuration
/// inspired by Caffeine (Java) and other modern caching libraries.
///
/// Example:
/// ```dart
/// final cache = CacheBuilder<String, User>()
///   .maximumSize(1000)
///   .expireAfterWrite(Duration(minutes: 30))
///   .expireAfterAccess(Duration(minutes: 10))
///   .evictionPolicy(EvictionPolicyType.lfu)
///   .recordStats()
///   .removalListener((key, value, cause) => log('Removed: $key'))
///   .build();
///
/// // Or with auto-loading
/// final loadingCache = CacheBuilder<String, User>()
///   .maximumSize(1000)
///   .expireAfterWrite(Duration(minutes: 30))
///   .buildAsync((key) => api.fetchUser(key));
/// ```
class CacheBuilder<K, V> {
  int? _maxEntries;
  Duration? _expireAfterWrite;
  Duration? _expireAfterAccess;
  EvictionPolicyType _evictionPolicy = EvictionPolicyType.lru;
  bool _recordStats = false;
  void Function(K key, V? value, RemovalCause cause)? _removalListener;
  bool _enableAutoTrim = false;
  Duration _autoTrimInterval = const Duration(minutes: 5);

  /// Sets the maximum number of entries in the cache.
  ///
  /// When the limit is exceeded, entries are evicted according
  /// to the eviction policy.
  CacheBuilder<K, V> maximumSize(int maxEntries) {
    _maxEntries = maxEntries;
    return this;
  }

  /// Sets the TTL for entries after they are written.
  ///
  /// Entries expire this duration after being set or updated.
  CacheBuilder<K, V> expireAfterWrite(Duration duration) {
    _expireAfterWrite = duration;
    return this;
  }

  /// Sets the TTL for entries after they are accessed.
  ///
  /// Note: This is currently tracked via expireAfterWrite;
  /// true access-based expiration requires additional tracking.
  CacheBuilder<K, V> expireAfterAccess(Duration duration) {
    _expireAfterAccess = duration;
    return this;
  }

  /// Sets the eviction policy for the cache.
  CacheBuilder<K, V> evictionPolicy(EvictionPolicyType policy) {
    _evictionPolicy = policy;
    return this;
  }

  /// Enables statistics recording for the cache.
  CacheBuilder<K, V> recordStats() {
    _recordStats = true;
    return this;
  }

  /// Sets a listener called when entries are removed.
  CacheBuilder<K, V> removalListener(
    void Function(K key, V? value, RemovalCause cause) listener,
  ) {
    _removalListener = listener;
    return this;
  }

  /// Enables automatic trimming of expired entries.
  CacheBuilder<K, V> enableAutoTrim({
    Duration interval = const Duration(minutes: 5),
  }) {
    _enableAutoTrim = true;
    _autoTrimInterval = interval;
    return this;
  }

  /// Builds a cache with the configured settings.
  BuiltCache<K, V> build() {
    final config = CacheConfig(
      defaultTTL: _expireAfterWrite ?? _expireAfterAccess,
      maxEntries: _maxEntries,
      enableAutoTrim: _enableAutoTrim,
      autoTrimInterval: _autoTrimInterval,
      evictionPolicy: _evictionPolicy,
      recordStats: _recordStats,
      onEvicted: _removalListener != null
          ? (key, value) {
              _removalListener!(key as K, value as V?, RemovalCause.evicted);
            }
          : null,
    );

    return BuiltCache<K, V>(config: config);
  }

  /// Builds a loading cache that automatically loads values on miss.
  LoadingCache<K, V> buildAsync(CacheLoader<K, V> loader) {
    final config = CacheConfig(
      defaultTTL: _expireAfterWrite ?? _expireAfterAccess,
      maxEntries: _maxEntries,
      enableAutoTrim: _enableAutoTrim,
      autoTrimInterval: _autoTrimInterval,
      evictionPolicy: _evictionPolicy,
      recordStats: _recordStats,
    );

    return LoadingCache<K, V>(loader: loader, config: config);
  }

  /// Builds a synchronous loading cache.
  SyncLoadingCache<K, V> buildSync(V Function(K key) loader) {
    final config = CacheConfig(
      defaultTTL: _expireAfterWrite ?? _expireAfterAccess,
      maxEntries: _maxEntries,
      enableAutoTrim: _enableAutoTrim,
      autoTrimInterval: _autoTrimInterval,
      evictionPolicy: _evictionPolicy,
      recordStats: _recordStats,
    );

    return SyncLoadingCache<K, V>(loader: loader, config: config);
  }
}

/// Reasons why an entry was removed from the cache.
enum RemovalCause {
  /// Explicitly removed by the user.
  explicit,

  /// Replaced with a new value.
  replaced,

  /// Evicted due to capacity limits.
  evicted,

  /// Expired due to TTL.
  expired,

  /// Cache was cleared.
  cleared,
}

/// A cache built using [CacheBuilder].
class BuiltCache<K, V> {
  /// Creates a built cache with the specified config.
  BuiltCache({required this.config}) : _store = {};

  /// The cache configuration.
  final CacheConfig config;

  final Map<String, _BuiltCacheEntry<V>> _store;
  final EvictionPolicy _policy = EvictionPolicy(EvictionPolicyType.lru);

  /// Gets a value from the cache.
  V? get(K key) {
    final keyStr = _keyToString(key);
    final entry = _store[keyStr];
    if (entry == null) return null;

    if (entry.isExpired) {
      remove(key);
      return null;
    }

    _policy.onAccess(keyStr);
    return entry.value;
  }

  /// Gets a value or returns [defaultValue] if not present.
  V getOr(K key, V defaultValue) {
    return get(key) ?? defaultValue;
  }

  /// Gets a value, computing it if not present.
  V getOrSet(K key, V Function() compute, {Duration? ttl}) {
    final existing = get(key);
    if (existing != null) return existing;

    final value = compute();
    set(key, value, ttl: ttl);
    return value;
  }

  /// Sets a value in the cache.
  void set(K key, V value, {Duration? ttl}) {
    final keyStr = _keyToString(key);
    final effectiveTTL = ttl ?? config.defaultTTL;

    _store[keyStr] = _BuiltCacheEntry(
      value,
      expiresAt: effectiveTTL != null
          ? DateTime.now().add(effectiveTTL)
          : null,
    );

    _policy.onAdd(keyStr);
    _enforceMaxEntries();
  }

  /// Checks if a key exists in the cache.
  bool containsKey(K key) {
    final keyStr = _keyToString(key);
    final entry = _store[keyStr];
    if (entry == null) return false;
    if (entry.isExpired) {
      remove(key);
      return false;
    }
    return true;
  }

  /// Removes a key from the cache.
  V? remove(K key) {
    final keyStr = _keyToString(key);
    final entry = _store.remove(keyStr);
    _policy.onRemove(keyStr);
    return entry?.value;
  }

  /// Clears all entries from the cache.
  void clear() {
    _store.clear();
    _policy.clear();
  }

  /// Returns all keys in the cache.
  List<K> get keys {
    _trimExpired();
    return _store.keys.map(_stringToKey).toList();
  }

  /// Returns the number of entries.
  int get length {
    _trimExpired();
    return _store.length;
  }

  /// Whether the cache is empty.
  bool get isEmpty => length == 0;

  /// Whether the cache has entries.
  bool get isNotEmpty => !isEmpty;

  void _enforceMaxEntries() {
    final maxEntries = config.maxEntries;
    if (maxEntries == null) return;

    while (_store.length > maxEntries) {
      final candidate = _policy.getEvictionCandidate();
      if (candidate == null) break;
      _store.remove(candidate);
      _policy.onRemove(candidate);
    }
  }

  void _trimExpired() {
    final expiredKeys = <String>[];
    for (final entry in _store.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }
    for (final key in expiredKeys) {
      _store.remove(key);
      _policy.onRemove(key);
    }
  }

  String _keyToString(K key) => key.toString();
  K _stringToKey(String key) => key as K;

  /// Disposes the cache.
  void dispose() {
    clear();
  }
}

class _BuiltCacheEntry<V> {
  _BuiltCacheEntry(this.value, {this.expiresAt});

  final V value;
  final DateTime? expiresAt;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}
