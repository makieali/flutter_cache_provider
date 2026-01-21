/// A flexible, production-ready caching solution for Flutter and Dart.
///
/// This package provides enterprise-grade caching with:
/// - Type-safe caching with automatic TTL expiration
/// - Hierarchical (path-based) key organization
/// - Multiple eviction policies (LRU, LFU, FIFO)
/// - Event streams for reactive updates
/// - Hit/miss metrics with latency tracking
/// - Stale-while-revalidate pattern
/// - Auto-loading cache (Caffeine-style)
/// - Tiered caching (L1/L2 memory + persistence)
/// - Cache warming APIs
/// - Fluent builder API
/// - Namespace/partition support
/// - Flutter Provider integration
///
/// ## Quick Start
///
/// ```dart
/// import 'package:flutter_cache_provider/flutter_cache_provider.dart';
///
/// // Create a cache
/// final cache = Cache();
///
/// // Store values with TTL
/// cache.set('user_123', userProfile, ttl: Duration(minutes: 30));
///
/// // Retrieve values
/// final user = cache.get<UserProfile>('user_123');
///
/// // Use hierarchical keys
/// cache.setPath(['users', '123', 'preferences'], prefs);
/// final prefs = cache.getPath<Preferences>(['users', '123', 'preferences']);
/// ```
///
/// ## Builder Pattern
///
/// ```dart
/// final cache = CacheBuilder<String, User>()
///   .maximumSize(1000)
///   .expireAfterWrite(Duration(minutes: 30))
///   .evictionPolicy(EvictionPolicyType.lfu)
///   .recordStats()
///   .removalListener((key, value, cause) => log('Removed: $key'))
///   .build();
/// ```
///
/// ## Auto-Loading Cache
///
/// ```dart
/// final userCache = LoadingCache<String, User>(
///   loader: (id) => api.fetchUser(id),
///   config: CacheConfig(defaultTTL: Duration(minutes: 30)),
/// );
///
/// // Automatically fetches user if not cached
/// final user = await userCache.get('user_123');
/// ```
///
/// ## Tiered Caching (L1/L2)
///
/// ```dart
/// final cache = TieredCache(
///   l1Config: CacheConfig(maxEntries: 100),
///   l2Store: FileCacheStore(directory: Directory('cache')),
/// );
///
/// // Fast L1 lookup, falls back to persistent L2
/// final value = await cache.get<MyType>('key');
/// ```
///
/// ## Event Streams
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
///   }
/// });
/// ```
///
/// ## Namespaces
///
/// ```dart
/// final cache = NamespacedCache();
/// final userCache = cache.namespace('users');
/// final sessionCache = cache.namespace('sessions');
///
/// userCache.set('123', userData);  // Isolated from sessions
/// sessionCache.clear();  // Only clears sessions
/// ```
///
/// ## With Flutter Provider
///
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => CacheProvider(),
///   child: MyApp(),
/// );
///
/// // In your widget
/// final cache = context.watch<CacheProvider>();
/// final user = cache.get<User>('current_user');
/// ```
library flutter_cache_provider;

// Core
export 'src/cache.dart';
export 'src/cache_config.dart';
export 'src/cache_entry.dart';
export 'src/cache_stats.dart';

// Flutter integration
export 'src/cache_provider.dart';

// Events
export 'src/cache_event.dart';

// Metrics
export 'src/cache_metrics.dart';

// Eviction policies
export 'src/eviction_policy.dart';

// Loading cache
export 'src/loading_cache.dart';

// Builder
export 'src/cache_builder.dart';

// Persistence
export 'src/cache_store.dart';

// Tiered caching
export 'src/tiered_cache.dart';

// Namespaces
export 'src/namespaced_cache.dart';
