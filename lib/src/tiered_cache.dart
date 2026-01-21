import 'dart:async';

import 'package:flutter_cache_provider/src/cache.dart';
import 'package:flutter_cache_provider/src/cache_config.dart';
import 'package:flutter_cache_provider/src/cache_entry.dart';
import 'package:flutter_cache_provider/src/cache_store.dart';

/// A two-level cache with fast L1 (in-memory) and slower L2 (persistent) tiers.
///
/// The tiered cache provides:
/// - Fast access for frequently used data (L1)
/// - Persistent storage for overflow and durability (L2)
/// - Automatic promotion of data from L2 to L1 on access
///
/// Example:
/// ```dart
/// final cache = TieredCache(
///   l1Config: CacheConfig(maxEntries: 100, defaultTTL: Duration(minutes: 5)),
///   l2Store: FileCacheStore(directory: Directory('cache')),
/// );
///
/// // Value stored in both L1 and L2
/// await cache.set('key', value);
///
/// // Fast retrieval from L1, falls back to L2
/// final value = await cache.get<MyType>('key');
/// ```
class TieredCache {
  /// Creates a tiered cache with L1 in-memory and L2 persistent storage.
  ///
  /// [l1Config] configures the in-memory L1 cache.
  /// [l2Store] provides the persistent L2 storage backend.
  /// [writeThrough] if true, writes go to both L1 and L2 (default: true).
  /// [promoteOnAccess] if true, L2 hits are promoted to L1 (default: true).
  TieredCache({
    CacheConfig? l1Config,
    required this.l2Store,
    this.writeThrough = true,
    this.promoteOnAccess = true,
  }) : l1 = Cache(config: l1Config ?? const CacheConfig(maxEntries: 100));

  /// The L1 in-memory cache.
  final Cache l1;

  /// The L2 persistent store.
  final CacheStore l2Store;

  /// Whether writes go to both L1 and L2.
  final bool writeThrough;

  /// Whether L2 hits are promoted to L1.
  final bool promoteOnAccess;

  /// Gets a value from the cache.
  ///
  /// Checks L1 first, then L2. If found in L2 and [promoteOnAccess] is true,
  /// the value is promoted to L1 for faster future access.
  Future<T?> get<T>(String key) async {
    // Check L1 first
    final l1Value = l1.get<T>(key);
    if (l1Value != null) {
      return l1Value;
    }

    // Check L2
    final l2Entry = await l2Store.get(key);
    if (l2Entry == null) {
      return null;
    }

    // Check if L2 entry is expired
    if (l2Entry.isExpired) {
      await l2Store.remove(key);
      return null;
    }

    // Promote to L1
    if (promoteOnAccess) {
      l1.set(key, l2Entry.value, ttl: l2Entry.timeToLive);
    }

    return l2Entry.value as T;
  }

  /// Gets a value, returning [defaultValue] if not found.
  Future<T> getOr<T>(String key, T defaultValue) async {
    final value = await get<T>(key);
    return value ?? defaultValue;
  }

  /// Gets a value, computing it if not present.
  Future<T> getOrSet<T>(
    String key,
    Future<T> Function() compute, {
    Duration? ttl,
  }) async {
    final existing = await get<T>(key);
    if (existing != null) {
      return existing;
    }

    final value = await compute();
    await set(key, value, ttl: ttl);
    return value;
  }

  /// Sets a value in the cache.
  ///
  /// If [writeThrough] is true, writes to both L1 and L2.
  /// Otherwise, only writes to L1 (write-behind pattern).
  Future<void> set<T>(String key, T value, {Duration? ttl}) async {
    l1.set(key, value, ttl: ttl);

    if (writeThrough) {
      final entry = CacheEntry<T>(value, ttl: ttl);
      await l2Store.put(key, entry);
    }
  }

  /// Sets a permanent value that never expires.
  Future<void> setPermanent<T>(String key, T value) async {
    l1.setPermanent(key, value);

    if (writeThrough) {
      await l2Store.put(key, CacheEntry<T>.permanent(value));
    }
  }

  /// Checks if a key exists in either tier.
  Future<bool> containsKey(String key) async {
    if (l1.containsKey(key)) {
      return true;
    }
    return l2Store.containsKey(key);
  }

  /// Removes a key from both tiers.
  Future<T?> remove<T>(String key) async {
    final l1Value = l1.remove<T>(key);
    await l2Store.remove(key);
    return l1Value;
  }

  /// Clears all entries from both tiers.
  Future<void> clear() async {
    l1.clear();
    await l2Store.clear();
  }

  /// Returns all keys from both tiers.
  Future<List<String>> get keys async {
    final l1Keys = l1.keys.toSet();
    final l2Keys = (await l2Store.keys()).toSet();
    return l1Keys.union(l2Keys).toList();
  }

  /// Flushes L1 entries to L2 and clears L1.
  ///
  /// Useful for reducing memory usage while preserving data.
  Future<void> flushL1ToL2() async {
    for (final key in l1.keys) {
      final entry = l1.getEntry<dynamic>(key);
      if (entry != null) {
        await l2Store.put(key, entry);
      }
    }
    l1.clear();
  }

  /// Warms up L1 from L2 with the specified keys.
  Future<void> warmUpL1(List<String> keys) async {
    for (final key in keys) {
      final entry = await l2Store.get(key);
      if (entry != null && entry.isValid) {
        l1.set(key, entry.value, ttl: entry.timeToLive);
      }
    }
  }

  /// Returns statistics for both tiers.
  Future<TieredCacheStats> getStats() async {
    return TieredCacheStats(
      l1Stats: l1.getStats(),
      l2EntryCount: await l2Store.length,
    );
  }

  /// Disposes both tiers and releases resources.
  Future<void> dispose() async {
    l1.dispose();
    await l2Store.close();
  }
}

/// Statistics for a tiered cache.
class TieredCacheStats {
  /// Creates tiered cache statistics.
  const TieredCacheStats({
    required this.l1Stats,
    required this.l2EntryCount,
  });

  /// Statistics for the L1 cache.
  final dynamic l1Stats;

  /// Number of entries in L2.
  final int l2EntryCount;

  /// Total entries across both tiers.
  int get totalEntries => (l1Stats.totalEntries as int) + l2EntryCount;

  @override
  String toString() {
    return 'TieredCacheStats(l1: ${l1Stats.totalEntries}, l2: $l2EntryCount)';
  }
}

/// Write policy for tiered cache.
enum TieredWritePolicy {
  /// Write to both L1 and L2 synchronously.
  writeThrough,

  /// Write to L1 only, async write to L2.
  writeBehind,

  /// Write to L1 only, L2 on eviction.
  writeOnEviction,
}
