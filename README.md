<div align="center">

# flutter_cache_provider

<p align="center">
  <strong>A production-ready, enterprise-grade caching solution for Flutter and Dart with advanced features.</strong>
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_cache_provider">
    <img src="https://img.shields.io/pub/v/flutter_cache_provider.svg?style=for-the-badge&logo=dart&logoColor=white&labelColor=0175C2&color=13B9FD" alt="pub package">
  </a>
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge" alt="License: MIT">
  </a>
  <a href="https://github.com/makieali/flutter_cache_provider/actions">
    <img src="https://img.shields.io/badge/tests-118%20passed-success?style=for-the-badge&logo=github-actions&logoColor=white" alt="Tests">
  </a>
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-advanced-features">Advanced</a> •
  <a href="#-api">API</a>
</p>

---

</div>

## Features

<table>
<tr>
<td width="33%">

### Core Caching
- Type-safe generic caching
- TTL expiration per entry
- Hierarchical (path-based) keys
- Flutter Provider integration

</td>
<td width="33%">

### Advanced Patterns
- **Stale-While-Revalidate**
- **Auto-Loading Cache** (Caffeine-style)
- **Tiered Caching** (L1/L2)
- **Cache Warming**

</td>
<td width="33%">

### Enterprise Features
- **Event Streams** (reactive)
- **Metrics & Monitoring**
- **Multiple Eviction Policies**
- **Namespaces & Partitions**

</td>
</tr>
</table>

### Why flutter_cache_provider?

| Feature | flutter_cache_provider | Others |
|---------|----------------------|--------|
| Type-safe generics | Yes | Partial |
| Event streams | Yes | No |
| Hit/miss metrics | Yes | No |
| Stale-while-revalidate | Yes | No |
| Auto-loading cache | Yes | No |
| Tiered caching (L1/L2) | Yes | No |
| Multiple eviction policies | LRU, LFU, FIFO | LRU only |
| Prometheus export | Yes | No |
| Namespace support | Yes | No |
| Zero dependencies | Yes | No |

---

## Installation

```yaml
dependencies:
  flutter_cache_provider: ^1.0.0
```

```bash
flutter pub get
```

---

## Quick Start

### Basic Usage

```dart
import 'package:flutter_cache_provider/flutter_cache_provider.dart';

final cache = Cache();

// Store with TTL
cache.set('user_123', userProfile, ttl: Duration(minutes: 30));

// Retrieve (type-safe)
final user = cache.get<UserProfile>('user_123');

// Get with default
final count = cache.getOr<int>('counter', 0);

// Compute if absent
final data = cache.getOrSet('key', () => expensiveComputation());
```

### Builder Pattern (Caffeine-style)

```dart
final cache = CacheBuilder<String, User>()
    .maximumSize(1000)
    .expireAfterWrite(Duration(minutes: 30))
    .expireAfterAccess(Duration(minutes: 10))
    .evictionPolicy(EvictionPolicyType.lfu)
    .recordStats()
    .removalListener((key, value, cause) => log('Removed: $key ($cause)'))
    .build();
```

---

## Advanced Features

### Auto-Loading Cache

Automatically fetch values on cache miss (like Caffeine/Guava):

```dart
final userCache = LoadingCache<String, User>(
  loader: (id) => api.fetchUser(id),
  config: CacheConfig(
    defaultTTL: Duration(minutes: 30),
    maxEntries: 1000,
  ),
);

// Automatically fetches if not cached
final user = await userCache.get('user_123');

// Batch loading
final users = await userCache.getAll(['user_1', 'user_2', 'user_3']);

// Force refresh
final freshUser = await userCache.refresh('user_123');
```

### Stale-While-Revalidate

Return stale data immediately while refreshing in background:

```dart
final cache = Cache(config: CacheConfig(
  defaultTTL: Duration(minutes: 30),
  staleWhileRevalidate: true,
  staleTime: Duration(minutes: 15), // Stale after 15min, expired after 30min
));

// Returns stale data immediately, refreshes in background
final data = await cache.getStale<Data>(
  'key',
  () => api.fetchFreshData(),
);
```

### Tiered Caching (L1/L2)

Fast in-memory L1 with persistent L2 fallback:

```dart
final cache = TieredCache(
  l1Config: CacheConfig(maxEntries: 100, defaultTTL: Duration(minutes: 5)),
  l2Store: FileCacheStore(directory: Directory('cache')),
  writeThrough: true,    // Write to both tiers
  promoteOnAccess: true, // Promote L2 hits to L1
);

// Fast L1 lookup, falls back to L2
final value = await cache.get<MyData>('key');

// Warm up L1 from L2
await cache.warmUpL1(['key1', 'key2', 'key3']);

// Flush L1 to L2 (reduce memory)
await cache.flushL1ToL2();
```

### Event Streams

React to cache changes:

```dart
final cache = Cache(config: CacheConfig(enableEventStream: true));

cache.events.listen((event) {
  switch (event.type) {
    case CacheEventType.created:
      print('New: ${event.key}');
      break;
    case CacheEventType.expired:
      analytics.trackExpiry(event.key);
      break;
    case CacheEventType.evicted:
      print('Evicted: ${event.key}');
      break;
  }
});

// Filter specific events
cache.events.expirations.listen((e) => log('Expired: ${e.key}'));
cache.events.whereKey('important').listen((e) => notify());
cache.events.whereKeyPrefix('user_').listen((e) => syncUser(e.key));
```

### Metrics & Monitoring

Track cache performance:

```dart
final cache = Cache(config: CacheConfig(recordStats: true));

// ... use cache ...

final metrics = cache.metrics;
print('Hit ratio: ${metrics.hitRatioPercent}');  // "85.2%"
print('Total gets: ${metrics.gets}');
print('Evictions: ${metrics.evictions}');
print('P95 latency: ${metrics.p95GetLatency}');

// Prometheus export
print(metrics.toPrometheus(prefix: 'my_cache'));
// cache_hits_total 1523
// cache_misses_total 267
// cache_hit_ratio 0.851
// cache_get_latency_seconds{quantile="0.95"} 0.000042

// Pretty summary
print(metrics.summary);
```

### Multiple Eviction Policies

Choose the best policy for your use case:

```dart
// Least Recently Used (default)
final lruCache = Cache(config: CacheConfig(evictionPolicy: EvictionPolicyType.lru));

// Least Frequently Used (great for hot data)
final lfuCache = Cache(config: CacheConfig(evictionPolicy: EvictionPolicyType.lfu));

// First In First Out
final fifoCache = Cache(config: CacheConfig(evictionPolicy: EvictionPolicyType.fifo));

// Using builder
final cache = CacheBuilder<String, Data>()
    .maximumSize(1000)
    .evictionPolicy(EvictionPolicyType.lfu)
    .build();
```

### Namespaces & Partitions

Organize cache into isolated namespaces:

```dart
final cache = NamespacedCache();

final userCache = cache.namespace('users');
final sessionCache = cache.namespace('sessions');
final configCache = cache.namespace('config');

// Keys are isolated
userCache.set('123', userData);      // Actually stored as 'users::123'
sessionCache.set('abc', sessionData); // Actually stored as 'sessions::abc'

// Clear only one namespace
sessionCache.clear(); // Users and config unaffected

// Nested namespaces
final profileCache = userCache.sub('profiles');
profileCache.set('123', profile); // Stored as 'users::profiles::123'

// Stats per namespace
print('Users: ${userCache.length} entries');
print('Sessions: ${sessionCache.length} entries');
```

### Cache Warming

Pre-load frequently accessed data:

```dart
// Sync warming
cache.warmUp<Config>({
  'app_config': appConfig,
  'feature_flags': featureFlags,
  'theme': themeData,
});

// Async warming with loader
await cache.warmUpAsync<User>(
  ['user_1', 'user_2', 'user_3'],
  (id) => api.fetchUser(id),
  ttl: Duration(hours: 1),
);
```

### Persistence Layer

Implement custom storage backends:

```dart
// Built-in file store
final store = FileCacheStore(directory: Directory('cache'));

// Built-in memory store (for testing)
final store = MemoryCacheStore();

// Custom implementation
class RedisCacheStore implements CacheStore {
  @override
  Future<void> put(String key, CacheEntry entry) async { ... }

  @override
  Future<CacheEntry?> get(String key) async { ... }

  // ... other methods
}
```

---

## API Reference

### Basic Operations

```dart
cache.set('key', value);
cache.set('key', value, ttl: Duration(hours: 1));
cache.setPermanent('key', value);

final value = cache.get<T>('key');
final value = cache.getOr<T>('key', defaultValue);
final value = cache.getOrSet<T>('key', () => compute());
final value = await cache.getOrSetAsync<T>('key', () async => fetch());

final exists = cache.containsKey('key');
final removed = cache.remove<T>('key');
```

### Path-Based Operations

```dart
cache.setPath(['users', '123', 'profile'], profile);
final profile = cache.getPath<Profile>(['users', '123', 'profile']);

final keys = cache.getKeysWithPrefix(['users', '123']);
cache.removeWithPrefix(['users', '123']);
```

### Bulk Operations

```dart
cache.setAll<int>({'a': 1, 'b': 2, 'c': 3});
final values = cache.getAll<int>(['a', 'b', 'c']);
cache.removeAll(['a', 'b']);
```

### Cache Management

```dart
final keys = cache.keys;
final count = cache.length;

cache.clear();
cache.clear(preserve: {'important_key'});
cache.clearWhere((key, value) => shouldRemove(key, value));
cache.trimExpired();
cache.dispose();
```

### Entry Information

```dart
final entry = cache.getEntry<T>('key');
final ttl = cache.getTimeToLive('key');
final age = cache.getAge('key');

cache.extendTTL('key', Duration(hours: 1));
cache.refresh('key');
```

---

## Configuration

### Full Configuration

```dart
final cache = Cache(
  config: CacheConfig(
    defaultTTL: Duration(hours: 1),
    maxEntries: 1000,
    enableAutoTrim: true,
    autoTrimInterval: Duration(minutes: 5),
    evictionPolicy: EvictionPolicyType.lru,
    recordStats: true,
    enableEventStream: true,
    staleWhileRevalidate: true,
    staleTime: Duration(minutes: 30),
    onEvicted: (key, value) => log('Evicted: $key'),
  ),
);
```

### Preset Configurations

```dart
Cache(config: CacheConfig.permanent())      // No TTL
Cache(config: CacheConfig.shortLived())     // 5 min TTL
Cache(config: CacheConfig.longLived())      // 24 hour TTL
Cache(config: CacheConfig.highPerformance()) // LFU, metrics, 10K entries
```

---

## Flutter Integration

### With Provider

```dart
ChangeNotifierProvider(
  create: (_) => CacheProvider(
    config: CacheConfig(defaultTTL: Duration(minutes: 30)),
  ),
  child: MyApp(),
);

// In widget
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cache = context.watch<CacheProvider>();
    final user = cache.get<User>('current_user');

    return user != null ? UserProfile(user) : LoadingIndicator();
  }
}
```

---

## Real-World Example

```dart
class UserRepository {
  final _cache = LoadingCache<String, User>(
    loader: (id) => _api.fetchUser(id),
    config: CacheConfig(
      defaultTTL: Duration(minutes: 15),
      maxEntries: 500,
      evictionPolicy: EvictionPolicyType.lfu,
      recordStats: true,
    ),
  );

  Future<User> getUser(String id) => _cache.get(id);

  Future<List<User>> getUsers(List<String> ids) async {
    final map = await _cache.getAll(ids);
    return map.values.toList();
  }

  void invalidate(String id) => _cache.invalidate(id);

  void invalidateAll() => _cache.invalidateAllEntries();

  CacheMetrics get metrics => _cache.metrics;
}
```

---

## Contributing

Contributions welcome! Please submit a Pull Request.

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

<div align="center">

**[Back to Top](#flutter_cache_provider)**

Made with care for the Flutter community

</div>
