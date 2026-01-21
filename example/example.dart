// ignore_for_file: avoid_print, cascade_invocations

import 'package:flutter_cache_provider/flutter_cache_provider.dart';

/// Example demonstrating the flutter_cache_provider package.
void main() async {
  // ============================================
  // Basic Cache Usage
  // ============================================

  // Create a simple cache
  final cache = Cache();

  // Store values with TTL
  cache.set(
    'user_123',
    {'name': 'John', 'age': 30},
    ttl: const Duration(minutes: 30),
  );

  // Retrieve values
  final user = cache.get<Map<String, dynamic>>('user_123');
  print('User: $user');

  // Check if key exists
  if (cache.containsKey('user_123')) {
    print('User is cached');
  }

  // Use hierarchical keys
  cache.setPath(['users', '123', 'preferences'], {'theme': 'dark'});
  final prefs =
      cache.getPath<Map<String, dynamic>>(['users', '123', 'preferences']);
  print('Preferences: $prefs');

  // ============================================
  // Builder Pattern
  // ============================================

  final typedCache = CacheBuilder<String, String>()
      .maximumSize(1000)
      .expireAfterWrite(const Duration(minutes: 30))
      .evictionPolicy(EvictionPolicyType.lru)
      .recordStats()
      .removalListener((key, value, cause) {
        print('Removed: $key (reason: $cause)');
      })
      .build();

  typedCache.set('greeting', 'Hello, World!');
  print('Greeting: ${typedCache.get('greeting')}');

  // ============================================
  // Auto-Loading Cache
  // ============================================

  final loadingCache = LoadingCache<String, Map<String, dynamic>>(
    loader: (id) async {
      // Simulate API call
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return {
        'id': id,
        'name': 'User $id',
        'loadedAt': DateTime.now().toIso8601String(),
      };
    },
    config: const CacheConfig(defaultTTL: Duration(minutes: 30)),
  );

  // Automatically fetches if not cached
  final loadedUser = await loadingCache.get('user_456');
  print('Loaded user: $loadedUser');

  // Second call returns cached value
  final cachedUser = await loadingCache.get('user_456');
  print('Cached user: $cachedUser');

  // ============================================
  // Event Streams
  // ============================================

  final eventCache = Cache(
    config: const CacheConfig(enableEventStream: true),
  );

  // Listen to cache events
  eventCache.events.listen((event) {
    print('Cache event: ${event.type} - ${event.key}');
  });

  eventCache.set('key1', 'value1');
  eventCache.set('key2', 'value2');
  eventCache.remove<String>('key1');

  // ============================================
  // Namespaced Cache
  // ============================================

  final namespacedCache = NamespacedCache();
  final userNamespace = namespacedCache.namespace('users');
  final sessionNamespace = namespacedCache.namespace('sessions');

  // Each namespace is isolated
  userNamespace.set('123', {'name': 'Alice'});
  sessionNamespace.set('abc', {'token': 'xyz'});

  print('User 123: ${userNamespace.get<Map<String, dynamic>>('123')}');
  print('Session abc: ${sessionNamespace.get<Map<String, dynamic>>('abc')}');

  // Clear only one namespace
  sessionNamespace.clear();
  print(
    'Sessions cleared, but user still exists: '
    '${userNamespace.get<Map<String, dynamic>>('123')}',
  );

  // ============================================
  // Cache Metrics
  // ============================================

  final metricsCache = Cache(
    config: const CacheConfig(
      maxEntries: 100,
      recordStats: true,
    ),
  );

  // Generate some hits and misses
  metricsCache.set('a', 1);
  metricsCache.set('b', 2);
  metricsCache.get<int>('a'); // hit
  metricsCache.get<int>('a'); // hit
  metricsCache.get<int>('c'); // miss

  final metrics = metricsCache.metrics;
  print('Cache metrics:');
  print('  Hits: ${metrics.hits}');
  print('  Misses: ${metrics.misses}');
  print('  Hit ratio: ${(metrics.hitRatio * 100).toStringAsFixed(1)}%');

  // ============================================
  // Cleanup
  // ============================================

  cache.dispose();
  typedCache.dispose();
  loadingCache.dispose();
  eventCache.dispose();
  namespacedCache.dispose();
  metricsCache.dispose();

  print('Example completed!');
}
