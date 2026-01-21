import 'package:flutter_cache_provider/src/cache.dart';
import 'package:flutter_cache_provider/src/cache_config.dart';
import 'package:flutter_cache_provider/src/cache_entry.dart';

/// A cache partitioned into namespaces for organized key management.
///
/// Namespaces allow you to:
/// - Group related cache entries logically
/// - Clear specific groups without affecting others
/// - Apply different TTLs to different namespaces
/// - Avoid key collisions between different parts of your app
///
/// Example:
/// ```dart
/// final cache = NamespacedCache();
///
/// // Create namespaces
/// final userCache = cache.namespace('users');
/// final sessionCache = cache.namespace('sessions');
///
/// // Each namespace has isolated keys
/// userCache.set('123', userData);  // key = 'users::123'
/// sessionCache.set('abc', sessionData);  // key = 'sessions::abc'
///
/// // Clear only user cache
/// userCache.clear();
/// ```
class NamespacedCache {
  /// Creates a namespaced cache with optional [config].
  NamespacedCache({CacheConfig? config}) : _cache = Cache(config: config);

  /// Creates a namespaced cache wrapping an existing [Cache].
  NamespacedCache.wrap(this._cache);

  final Cache _cache;

  /// The underlying cache.
  Cache get cache => _cache;

  /// The namespace separator used in keys.
  static const String separator = '::';

  /// Created namespace views.
  final Map<String, CacheNamespace> _namespaces = {};

  /// Gets or creates a namespace view.
  ///
  /// The namespace provides a scoped view of the cache where all
  /// keys are automatically prefixed with the namespace name.
  CacheNamespace namespace(String name) {
    return _namespaces.putIfAbsent(
      name,
      () => CacheNamespace._(this, name),
    );
  }

  /// Creates a nested namespace path.
  ///
  /// Example:
  /// ```dart
  /// final cache = namespacePath(['app', 'users', 'profile']);
  /// // Keys will be prefixed with 'app::users::profile::'
  /// ```
  CacheNamespace namespacePath(List<String> path) {
    if (path.isEmpty) {
      throw ArgumentError('Namespace path cannot be empty');
    }
    return namespace(path.join(separator));
  }

  /// Clears a specific namespace.
  void clearNamespace(String name) {
    final prefix = '$name$separator';
    final keysToRemove = _cache.keys
        .where((key) => key.startsWith(prefix))
        .toList();

    for (final key in keysToRemove) {
      _cache.remove<dynamic>(key);
    }
  }

  /// Returns all registered namespace names.
  List<String> get namespaceNames => _namespaces.keys.toList();

  /// Returns the count of entries in a namespace.
  int countInNamespace(String name) {
    final prefix = '$name$separator';
    return _cache.keys.where((key) => key.startsWith(prefix)).length;
  }

  /// Returns all keys in a namespace.
  List<String> keysInNamespace(String name) {
    final prefix = '$name$separator';
    return _cache.keys
        .where((key) => key.startsWith(prefix))
        .map((key) => key.substring(prefix.length))
        .toList();
  }

  /// Disposes the cache and all namespaces.
  void dispose() {
    _namespaces.clear();
    _cache.dispose();
  }
}

/// A scoped view of a cache within a namespace.
///
/// All operations are automatically prefixed with the namespace,
/// providing isolation between different parts of your application.
class CacheNamespace {
  CacheNamespace._(this._parent, this.name);

  final NamespacedCache _parent;

  /// The name of this namespace.
  final String name;

  Cache get _cache => _parent._cache;

  String _prefixKey(String key) => '$name${NamespacedCache.separator}$key';

  /// Gets a value from this namespace.
  T? get<T>(String key) {
    return _cache.get<T>(_prefixKey(key));
  }

  /// Gets a value or returns [defaultValue] if not found.
  T getOr<T>(String key, T defaultValue) {
    return _cache.getOr<T>(_prefixKey(key), defaultValue);
  }

  /// Gets a value, computing it if not present.
  T getOrSet<T>(String key, T Function() compute, {Duration? ttl}) {
    return _cache.getOrSet<T>(_prefixKey(key), compute, ttl: ttl);
  }

  /// Async version of [getOrSet].
  Future<T> getOrSetAsync<T>(
    String key,
    Future<T> Function() compute, {
    Duration? ttl,
  }) {
    return _cache.getOrSetAsync<T>(_prefixKey(key), compute, ttl: ttl);
  }

  /// Sets a value in this namespace.
  void set<T>(String key, T value, {Duration? ttl}) {
    _cache.set<T>(_prefixKey(key), value, ttl: ttl);
  }

  /// Sets a permanent value that never expires.
  void setPermanent<T>(String key, T value) {
    _cache.setPermanent<T>(_prefixKey(key), value);
  }

  /// Checks if a key exists in this namespace.
  bool containsKey(String key) {
    return _cache.containsKey(_prefixKey(key));
  }

  /// Removes a key from this namespace.
  T? remove<T>(String key) {
    return _cache.remove<T>(_prefixKey(key));
  }

  /// Clears all entries in this namespace.
  void clear() {
    _parent.clearNamespace(name);
  }

  /// Returns all keys in this namespace (without prefix).
  List<String> get keys => _parent.keysInNamespace(name);

  /// Returns the number of entries in this namespace.
  int get length => _parent.countInNamespace(name);

  /// Whether this namespace is empty.
  bool get isEmpty => length == 0;

  /// Whether this namespace has entries.
  bool get isNotEmpty => !isEmpty;

  /// Gets the cache entry for a key.
  CacheEntry<T>? getEntry<T>(String key) {
    return _cache.getEntry<T>(_prefixKey(key));
  }

  /// Gets the remaining TTL for a key.
  Duration? getTimeToLive(String key) {
    return _cache.getTimeToLive(_prefixKey(key));
  }

  /// Extends the TTL of an entry.
  bool extendTTL(String key, Duration additionalTime) {
    return _cache.extendTTL(_prefixKey(key), additionalTime);
  }

  /// Refreshes an entry's TTL.
  bool refresh(String key, {Duration? ttl}) {
    return _cache.refresh(_prefixKey(key), ttl: ttl);
  }

  /// Gets multiple values by keys.
  Map<String, T> getAll<T>(List<String> keys) {
    final prefixedKeys = keys.map(_prefixKey).toList();
    final result = _cache.getAll<T>(prefixedKeys);

    // Remove prefix from returned keys
    final prefix = '$name${NamespacedCache.separator}';
    return Map.fromEntries(
      result.entries.map(
        (e) => MapEntry(e.key.substring(prefix.length), e.value),
      ),
    );
  }

  /// Sets multiple values.
  void setAll<T>(Map<String, T> entries, {Duration? ttl}) {
    final prefixed = Map.fromEntries(
      entries.entries.map((e) => MapEntry(_prefixKey(e.key), e.value)),
    );
    _cache.setAll<T>(prefixed, ttl: ttl);
  }

  /// Creates a sub-namespace within this namespace.
  ///
  /// Example:
  /// ```dart
  /// final users = cache.namespace('users');
  /// final profiles = users.sub('profiles');
  /// // Keys will be prefixed with 'users::profiles::'
  /// ```
  CacheNamespace sub(String childName) {
    return _parent.namespace('$name${NamespacedCache.separator}$childName');
  }

  @override
  String toString() => 'CacheNamespace($name)';
}
