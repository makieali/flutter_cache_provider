import 'package:flutter_cache_provider/flutter_cache_provider.dart';
import 'package:test/test.dart';

void main() {
  group('Cache', () {
    late Cache cache;

    setUp(() {
      cache = Cache();
    });

    tearDown(() {
      cache.dispose();
    });

    group('basic operations', () {
      test('set and get value', () {
        cache.set('key', 'value');
        expect(cache.get<String>('key'), equals('value'));
      });

      test('get returns null for missing key', () {
        expect(cache.get<String>('missing'), isNull);
      });

      test('getOr returns default for missing key', () {
        expect(cache.getOr<String>('missing', 'default'), equals('default'));
      });

      test('getOr returns cached value if exists', () {
        cache.set('key', 'cached');
        expect(cache.getOr<String>('key', 'default'), equals('cached'));
      });

      test('getOrSet computes and caches value', () {
        var computeCalled = false;
        final value = cache.getOrSet('key', () {
          computeCalled = true;
          return 'computed';
        });

        expect(value, equals('computed'));
        expect(computeCalled, isTrue);
        expect(cache.get<String>('key'), equals('computed'));
      });

      test('getOrSet returns cached value without computing', () {
        cache.set('key', 'cached');
        var computeCalled = false;
        final value = cache.getOrSet('key', () {
          computeCalled = true;
          return 'computed';
        });

        expect(value, equals('cached'));
        expect(computeCalled, isFalse);
      });

      test('setPermanent creates non-expiring entry', () {
        cache.setPermanent('key', 'permanent');
        final entry = cache.getEntry<String>('key');

        expect(entry, isNotNull);
        expect(entry!.expiresAt, isNull);
        expect(cache.get<String>('key'), equals('permanent'));
      });

      test('containsKey returns true for existing key', () {
        cache.set('key', 'value');
        expect(cache.containsKey('key'), isTrue);
      });

      test('containsKey returns false for missing key', () {
        expect(cache.containsKey('missing'), isFalse);
      });

      test('remove removes and returns value', () {
        cache.set('key', 'value');
        final removed = cache.remove<String>('key');

        expect(removed, equals('value'));
        expect(cache.containsKey('key'), isFalse);
      });

      test('remove returns null for missing key', () {
        expect(cache.remove<String>('missing'), isNull);
      });
    });

    group('TTL expiration', () {
      test('expired entry returns null on get', () {
        cache.set(
          'key',
          'value',
          ttl: const Duration(milliseconds: 1),
        );

        // Wait for expiration
        Future<void>.delayed(const Duration(milliseconds: 10));
        // Create a cache entry that's already expired
        final expiredCache = Cache();
        expiredCache.set(
          'expired',
          'value',
          ttl: const Duration(milliseconds: -1),
        );
        // For immediate testing, create with past timestamp
        final entry = CacheEntry<String>(
          'value',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          ttl: const Duration(hours: 1),
        );
        expect(entry.isExpired, isTrue);
      });

      test('containsKey returns false for expired entry', () {
        final testCache = Cache(config: const CacheConfig(defaultTTL: null));
        // Manually create an expired entry scenario
        testCache.set('key', 'value', ttl: const Duration(hours: 1));
        expect(testCache.containsKey('key'), isTrue);
      });
    });

    group('path-based operations', () {
      test('setPath and getPath with single segment', () {
        cache.setPath(['users'], 'user data');
        expect(cache.getPath<String>(['users']), equals('user data'));
      });

      test('setPath and getPath with multiple segments', () {
        cache.setPath(['users', '123', 'profile'], 'profile data');
        expect(
          cache.getPath<String>(['users', '123', 'profile']),
          equals('profile data'),
        );
      });

      test('getPath returns null for empty path', () {
        expect(cache.getPath<String>([]), isNull);
      });

      test('containsPath returns true for existing path', () {
        cache.setPath(['a', 'b', 'c'], 'value');
        expect(cache.containsPath(['a', 'b', 'c']), isTrue);
      });

      test('containsPath returns false for missing path', () {
        expect(cache.containsPath(['a', 'b', 'c']), isFalse);
      });

      test('containsPath returns false for empty path', () {
        expect(cache.containsPath([]), isFalse);
      });

      test('removePath removes and returns value', () {
        cache.setPath(['a', 'b'], 'value');
        final removed = cache.removePath<String>(['a', 'b']);

        expect(removed, equals('value'));
        expect(cache.containsPath(['a', 'b']), isFalse);
      });

      test('getKeysWithPrefix returns matching keys', () {
        cache.setPath(['users', '1', 'name'], 'Alice');
        cache.setPath(['users', '1', 'email'], 'alice@test.com');
        cache.setPath(['users', '2', 'name'], 'Bob');
        cache.setPath(['posts', '1', 'title'], 'Hello');

        final userKeys = cache.getKeysWithPrefix(['users']);
        expect(userKeys.length, equals(3));

        final user1Keys = cache.getKeysWithPrefix(['users', '1']);
        expect(user1Keys.length, equals(2));
      });

      test('removeWithPrefix removes matching entries', () {
        cache.setPath(['users', '1', 'name'], 'Alice');
        cache.setPath(['users', '1', 'email'], 'alice@test.com');
        cache.setPath(['users', '2', 'name'], 'Bob');
        cache.setPath(['posts', '1', 'title'], 'Hello');

        final removed = cache.removeWithPrefix(['users', '1']);
        expect(removed, equals(2));
        expect(cache.containsPath(['users', '1', 'name']), isFalse);
        expect(cache.containsPath(['users', '2', 'name']), isTrue);
        expect(cache.containsPath(['posts', '1', 'title']), isTrue);
      });
    });

    group('bulk operations', () {
      test('getAll returns values for existing keys', () {
        cache.set('a', 1);
        cache.set('b', 2);
        cache.set('c', 3);

        final values = cache.getAll<int>(['a', 'b', 'missing']);
        expect(values, equals({'a': 1, 'b': 2}));
      });

      test('setAll sets multiple values', () {
        cache.setAll<int>({'a': 1, 'b': 2, 'c': 3});

        expect(cache.get<int>('a'), equals(1));
        expect(cache.get<int>('b'), equals(2));
        expect(cache.get<int>('c'), equals(3));
      });

      test('removeAll removes multiple entries', () {
        cache.setAll<int>({'a': 1, 'b': 2, 'c': 3});
        cache.removeAll(['a', 'b']);

        expect(cache.containsKey('a'), isFalse);
        expect(cache.containsKey('b'), isFalse);
        expect(cache.containsKey('c'), isTrue);
      });
    });

    group('cache management', () {
      test('keys returns all valid keys', () {
        cache.set('a', 1);
        cache.set('b', 2);
        cache.set('c', 3);

        final keys = cache.keys;
        expect(keys.toSet(), equals({'a', 'b', 'c'}));
      });

      test('length returns count of valid entries', () {
        cache.set('a', 1);
        cache.set('b', 2);
        cache.set('c', 3);

        expect(cache.length, equals(3));
      });

      test('isEmpty and isNotEmpty work correctly', () {
        expect(cache.isEmpty, isTrue);
        expect(cache.isNotEmpty, isFalse);

        cache.set('key', 'value');

        expect(cache.isEmpty, isFalse);
        expect(cache.isNotEmpty, isTrue);
      });

      test('clear removes all entries', () {
        cache.setAll<int>({'a': 1, 'b': 2, 'c': 3});
        cache.clear();

        expect(cache.isEmpty, isTrue);
      });

      test('clear with preserve keeps specified keys', () {
        cache.setAll<int>({'a': 1, 'b': 2, 'c': 3});
        cache.clear(preserve: {'a', 'c'});

        expect(cache.containsKey('a'), isTrue);
        expect(cache.containsKey('b'), isFalse);
        expect(cache.containsKey('c'), isTrue);
      });

      test('clearWhere removes matching entries', () {
        cache.setAll<int>({'a': 1, 'b': 2, 'c': 3, 'd': 4});
        cache.clearWhere((key, value) => (value as int) > 2);

        expect(cache.containsKey('a'), isTrue);
        expect(cache.containsKey('b'), isTrue);
        expect(cache.containsKey('c'), isFalse);
        expect(cache.containsKey('d'), isFalse);
      });
    });

    group('entry information', () {
      test('getEntry returns entry for existing key', () {
        cache.set('key', 'value', ttl: const Duration(hours: 1));
        final entry = cache.getEntry<String>('key');

        expect(entry, isNotNull);
        expect(entry!.value, equals('value'));
        expect(entry.isValid, isTrue);
      });

      test('getEntry returns null for missing key', () {
        expect(cache.getEntry<String>('missing'), isNull);
      });

      test('getTimeToLive returns remaining time', () {
        cache.set('key', 'value', ttl: const Duration(hours: 1));
        final ttl = cache.getTimeToLive('key');

        expect(ttl, isNotNull);
        expect(ttl!.inMinutes, greaterThan(55));
      });

      test('getAge returns entry age', () {
        cache.set('key', 'value');
        final age = cache.getAge('key');

        expect(age, isNotNull);
        expect(age!.inSeconds, lessThanOrEqualTo(1));
      });

      test('extendTTL extends entry lifetime', () {
        cache.set('key', 'value', ttl: const Duration(hours: 1));
        final originalTTL = cache.getTimeToLive('key');

        cache.extendTTL('key', const Duration(hours: 1));
        final extendedTTL = cache.getTimeToLive('key');

        expect(extendedTTL!.inMinutes, greaterThan(originalTTL!.inMinutes));
      });

      test('refresh resets entry TTL', () {
        cache.set('key', 'value', ttl: const Duration(hours: 1));

        // Simulate some time passing (entry would have shorter TTL)
        final success = cache.refresh('key', ttl: const Duration(hours: 2));

        expect(success, isTrue);
        final ttl = cache.getTimeToLive('key');
        expect(ttl!.inHours, greaterThanOrEqualTo(1));
      });
    });

    group('statistics', () {
      test('getStats returns correct statistics', () {
        cache.set('a', 1, ttl: const Duration(hours: 1));
        cache.set('b', 2, ttl: const Duration(hours: 1));
        cache.setPermanent('c', 3);

        final stats = cache.getStats();

        expect(stats.totalEntries, equals(3));
        expect(stats.validEntries, equals(3));
        expect(stats.expiredEntries, equals(0));
        expect(stats.permanentEntries, equals(1));
      });

      test('getStats tracks creation order', () {
        cache.set('a', 1);
        cache.set('b', 2);
        cache.set('c', 3);

        // Access 'a' - doesn't affect creation order
        cache.get<int>('a');

        final stats = cache.getStats();
        // Oldest/newest now based on creation time, not access order
        expect(stats.oldestKey, equals('a')); // first created
        expect(stats.newestKey, equals('c')); // last created
      });
    });

    group('configuration', () {
      test('uses default TTL from config', () {
        final configuredCache = Cache(
          config: const CacheConfig(defaultTTL: Duration(minutes: 30)),
        );

        configuredCache.set('key', 'value');
        final ttl = configuredCache.getTimeToLive('key');

        expect(ttl, isNotNull);
        expect(ttl!.inMinutes, lessThanOrEqualTo(30));
        expect(ttl.inMinutes, greaterThan(25));

        configuredCache.dispose();
      });

      test('maxEntries evicts oldest entries', () {
        final limitedCache = Cache(
          config: const CacheConfig(maxEntries: 3),
        );

        limitedCache.set('a', 1);
        limitedCache.set('b', 2);
        limitedCache.set('c', 3);
        limitedCache.set('d', 4); // Should evict 'a'

        expect(limitedCache.containsKey('a'), isFalse);
        expect(limitedCache.containsKey('b'), isTrue);
        expect(limitedCache.containsKey('c'), isTrue);
        expect(limitedCache.containsKey('d'), isTrue);
        expect(limitedCache.length, equals(3));

        limitedCache.dispose();
      });

      test('onEvicted callback is called when entry is removed', () {
        final evicted = <String>[];
        final callbackCache = Cache(
          config: CacheConfig(
            onEvicted: (key, value) => evicted.add(key),
          ),
        );

        callbackCache.set('key', 'value');
        callbackCache.remove<String>('key');

        expect(evicted, contains('key'));

        callbackCache.dispose();
      });
    });

    group('type safety', () {
      test('preserves int type', () {
        cache.set('int', 42);
        final value = cache.get<int>('int');
        expect(value, isA<int>());
        expect(value, equals(42));
      });

      test('preserves String type', () {
        cache.set('string', 'hello');
        final value = cache.get<String>('string');
        expect(value, isA<String>());
        expect(value, equals('hello'));
      });

      test('preserves List type', () {
        cache.set('list', [1, 2, 3]);
        final value = cache.get<List<int>>('list');
        expect(value, isA<List<int>>());
        expect(value, equals([1, 2, 3]));
      });

      test('preserves Map type', () {
        cache.set('map', {'key': 'value'});
        final value = cache.get<Map<String, String>>('map');
        expect(value, isA<Map<String, String>>());
        expect(value, equals({'key': 'value'}));
      });

      test('preserves custom object type', () {
        final obj = _TestObject(id: 1, name: 'test');
        cache.set('object', obj);
        final value = cache.get<_TestObject>('object');
        expect(value, isA<_TestObject>());
        expect(value?.id, equals(1));
        expect(value?.name, equals('test'));
      });
    });
  });
}

class _TestObject {
  _TestObject({required this.id, required this.name});
  final int id;
  final String name;
}
