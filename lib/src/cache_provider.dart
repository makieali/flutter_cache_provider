import 'package:flutter/foundation.dart';
import 'package:flutter_cache_provider/src/cache.dart';
import 'package:flutter_cache_provider/src/cache_config.dart';
import 'package:flutter_cache_provider/src/cache_entry.dart';
import 'package:flutter_cache_provider/src/cache_stats.dart';

/// A Flutter-integrated cache that extends [ChangeNotifier].
///
/// This class wraps [Cache] and provides reactive updates to listeners
/// when the cache content changes. Perfect for use with Provider or
/// other state management solutions.
///
/// Example:
/// ```dart
/// // Create provider
/// final cacheProvider = CacheProvider();
///
/// // Use with Provider
/// ChangeNotifierProvider(
///   create: (_) => CacheProvider(),
///   child: MyApp(),
/// );
///
/// // In widget
/// final cache = context.watch<CacheProvider>();
/// final user = cache.get<User>('user_123');
/// ```
class CacheProvider extends ChangeNotifier {
  /// Creates a new cache provider with optional [config].
  CacheProvider({CacheConfig? config}) : _cache = Cache(config: config);

  final Cache _cache;

  /// The cache configuration.
  CacheConfig get config => _cache.config;

  // ============================================
  // Basic Get/Set Operations
  // ============================================

  /// Gets a value from the cache by [key].
  T? get<T>(String key) => _cache.get<T>(key);

  /// Gets a value from the cache, returning [defaultValue] if not found.
  T getOr<T>(String key, T defaultValue) => _cache.getOr(key, defaultValue);

  /// Gets a value from the cache, computing it if not present.
  T getOrSet<T>(
    String key,
    T Function() compute, {
    Duration? ttl,
  }) {
    final result = _cache.getOrSet(key, compute, ttl: ttl);
    notifyListeners();
    return result;
  }

  /// Asynchronous version of [getOrSet].
  Future<T> getOrSetAsync<T>(
    String key,
    Future<T> Function() compute, {
    Duration? ttl,
  }) async {
    final result = await _cache.getOrSetAsync(key, compute, ttl: ttl);
    notifyListeners();
    return result;
  }

  /// Sets a value in the cache with optional [ttl].
  void set<T>(String key, T value, {Duration? ttl}) {
    _cache.set(key, value, ttl: ttl);
    notifyListeners();
  }

  /// Sets a permanent value that never expires.
  void setPermanent<T>(String key, T value) {
    _cache.setPermanent(key, value);
    notifyListeners();
  }

  /// Checks if a key exists and is valid in the cache.
  bool containsKey(String key) => _cache.containsKey(key);

  /// Removes an entry from the cache.
  T? remove<T>(String key) {
    final result = _cache.remove<T>(key);
    notifyListeners();
    return result;
  }

  // ============================================
  // Hierarchical (Path-based) Operations
  // ============================================

  /// Gets a value using a hierarchical path.
  T? getPath<T>(List<String> path) => _cache.getPath<T>(path);

  /// Sets a value using a hierarchical path.
  void setPath<T>(List<String> path, T value, {Duration? ttl}) {
    _cache.setPath(path, value, ttl: ttl);
    notifyListeners();
  }

  /// Checks if a path exists in the cache.
  bool containsPath(List<String> path) => _cache.containsPath(path);

  /// Removes a value at the given path.
  T? removePath<T>(List<String> path) {
    final result = _cache.removePath<T>(path);
    notifyListeners();
    return result;
  }

  /// Gets all keys that match a path prefix.
  List<String> getKeysWithPrefix(List<String> pathPrefix) {
    return _cache.getKeysWithPrefix(pathPrefix);
  }

  /// Removes all entries that match a path prefix.
  int removeWithPrefix(List<String> pathPrefix) {
    final count = _cache.removeWithPrefix(pathPrefix);
    if (count > 0) notifyListeners();
    return count;
  }

  // ============================================
  // Bulk Operations
  // ============================================

  /// Gets multiple values by keys.
  Map<String, T> getAll<T>(List<String> keys) => _cache.getAll<T>(keys);

  /// Sets multiple values at once.
  void setAll<T>(Map<String, T> entries, {Duration? ttl}) {
    _cache.setAll(entries, ttl: ttl);
    notifyListeners();
  }

  /// Removes multiple entries by keys.
  void removeAll(List<String> keys) {
    _cache.removeAll(keys);
    notifyListeners();
  }

  // ============================================
  // Cache Management
  // ============================================

  /// All valid keys in the cache.
  List<String> get keys => _cache.keys;

  /// The number of valid entries in the cache.
  int get length => _cache.length;

  /// Whether the cache is empty.
  bool get isEmpty => _cache.isEmpty;

  /// Whether the cache has any entries.
  bool get isNotEmpty => _cache.isNotEmpty;

  /// Removes all expired entries from the cache.
  int trimExpired() {
    final count = _cache.trimExpired();
    if (count > 0) notifyListeners();
    return count;
  }

  /// Clears all entries from the cache.
  void clear({Set<String>? preserve}) {
    _cache.clear(preserve: preserve);
    notifyListeners();
  }

  /// Clears entries matching a predicate.
  void clearWhere(bool Function(String key, dynamic value) predicate) {
    _cache.clearWhere(predicate);
    notifyListeners();
  }

  // ============================================
  // Entry Information
  // ============================================

  /// Gets the cache entry metadata for a key.
  CacheEntry<T>? getEntry<T>(String key) => _cache.getEntry<T>(key);

  /// Gets the remaining TTL for an entry.
  Duration? getTimeToLive(String key) => _cache.getTimeToLive(key);

  /// Gets the age of an entry.
  Duration? getAge(String key) => _cache.getAge(key);

  /// Extends the TTL of an existing entry.
  bool extendTTL(String key, Duration additionalTime) {
    final result = _cache.extendTTL(key, additionalTime);
    if (result) notifyListeners();
    return result;
  }

  /// Refreshes an entry, resetting its TTL.
  bool refresh(String key, {Duration? ttl}) {
    final result = _cache.refresh(key, ttl: ttl);
    if (result) notifyListeners();
    return result;
  }

  // ============================================
  // Statistics
  // ============================================

  /// Gets statistics about the cache.
  CacheStats getStats() => _cache.getStats();

  /// Updates listeners without changing cache state.
  ///
  /// Useful when you want to notify listeners of external changes.
  void notifyUpdate() {
    notifyListeners();
  }

  @override
  void dispose() {
    _cache.dispose();
    super.dispose();
  }
}
