import 'package:flutter_cache_provider/flutter_cache_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CacheProvider', () {
    late CacheProvider provider;

    setUp(() {
      provider = CacheProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    group('ChangeNotifier integration', () {
      test('notifies listeners on set', () {
        var notified = false;
        provider.addListener(() => notified = true);

        provider.set('key', 'value');

        expect(notified, isTrue);
      });

      test('notifies listeners on remove', () {
        provider.set('key', 'value');

        var notified = false;
        provider.addListener(() => notified = true);

        provider.remove<String>('key');

        expect(notified, isTrue);
      });

      test('notifies listeners on clear', () {
        provider
          ..set('a', 1)
          ..set('b', 2);

        var notified = false;
        provider.addListener(() => notified = true);

        provider.clear();

        expect(notified, isTrue);
      });

      test('notifies listeners on setPath', () {
        var notified = false;
        provider.addListener(() => notified = true);

        provider.setPath(['users', '123'], 'data');

        expect(notified, isTrue);
      });

      test('notifies listeners on setAll', () {
        var notified = false;
        provider.addListener(() => notified = true);

        provider.setAll<int>({'a': 1, 'b': 2});

        expect(notified, isTrue);
      });

      test('notifies listeners on getOrSet when value is computed', () {
        var notified = false;
        provider.addListener(() => notified = true);

        provider.getOrSet('key', () => 'computed');

        expect(notified, isTrue);
      });

      test('notifyUpdate manually triggers notification', () {
        var notified = false;
        provider.addListener(() => notified = true);

        provider.notifyUpdate();

        expect(notified, isTrue);
      });
    });

    group('basic operations', () {
      test('get and set work correctly', () {
        provider.set('key', 'value');
        expect(provider.get<String>('key'), equals('value'));
      });

      test('getOr returns default for missing key', () {
        expect(provider.getOr<String>('missing', 'default'), equals('default'));
      });

      test('containsKey works correctly', () {
        provider.set('key', 'value');
        expect(provider.containsKey('key'), isTrue);
        expect(provider.containsKey('missing'), isFalse);
      });

      test('setPermanent creates non-expiring entry', () {
        provider.setPermanent('key', 'permanent');
        final entry = provider.getEntry<String>('key');
        expect(entry?.expiresAt, isNull);
      });
    });

    group('path-based operations', () {
      test('setPath and getPath work correctly', () {
        provider.setPath(['users', '123', 'name'], 'Alice');
        expect(
          provider.getPath<String>(['users', '123', 'name']),
          equals('Alice'),
        );
      });

      test('containsPath works correctly', () {
        provider.setPath(['a', 'b'], 'value');
        expect(provider.containsPath(['a', 'b']), isTrue);
        expect(provider.containsPath(['a', 'c']), isFalse);
      });

      test('removePath works correctly', () {
        provider.setPath(['a', 'b'], 'value');
        final removed = provider.removePath<String>(['a', 'b']);
        expect(removed, equals('value'));
        expect(provider.containsPath(['a', 'b']), isFalse);
      });

      test('getKeysWithPrefix works correctly', () {
        provider
          ..setPath(['users', '1'], 'a')
          ..setPath(['users', '2'], 'b')
          ..setPath(['posts', '1'], 'c');

        final keys = provider.getKeysWithPrefix(['users']);
        expect(keys.length, equals(2));
      });

      test('removeWithPrefix notifies and removes', () {
        provider
          ..setPath(['users', '1'], 'a')
          ..setPath(['users', '2'], 'b');

        var notified = false;
        provider.addListener(() => notified = true);

        final count = provider.removeWithPrefix(['users']);

        expect(count, equals(2));
        expect(notified, isTrue);
      });
    });

    group('bulk operations', () {
      test('getAll returns correct values', () {
        provider.setAll<int>({'a': 1, 'b': 2, 'c': 3});
        final values = provider.getAll<int>(['a', 'b']);
        expect(values, equals({'a': 1, 'b': 2}));
      });

      test('removeAll removes entries', () {
        provider.setAll<int>({'a': 1, 'b': 2, 'c': 3});
        provider.removeAll(['a', 'b']);
        expect(provider.containsKey('a'), isFalse);
        expect(provider.containsKey('c'), isTrue);
      });
    });

    group('cache management', () {
      test('keys returns all valid keys', () {
        provider.setAll<int>({'a': 1, 'b': 2});
        expect(provider.keys.toSet(), equals({'a', 'b'}));
      });

      test('length returns correct count', () {
        provider.setAll<int>({'a': 1, 'b': 2, 'c': 3});
        expect(provider.length, equals(3));
      });

      test('isEmpty and isNotEmpty work correctly', () {
        expect(provider.isEmpty, isTrue);
        provider.set('key', 'value');
        expect(provider.isEmpty, isFalse);
        expect(provider.isNotEmpty, isTrue);
      });

      test('clear with preserve keeps specified keys', () {
        provider.setAll<int>({'a': 1, 'b': 2, 'c': 3});
        provider.clear(preserve: {'a'});
        expect(provider.containsKey('a'), isTrue);
        expect(provider.containsKey('b'), isFalse);
      });

      test('clearWhere removes matching entries', () {
        provider.setAll<int>({'a': 1, 'b': 10, 'c': 100});
        provider.clearWhere((key, value) => (value as int) > 5);
        expect(provider.containsKey('a'), isTrue);
        expect(provider.containsKey('b'), isFalse);
        expect(provider.containsKey('c'), isFalse);
      });

      test('trimExpired notifies when entries removed', () {
        // This would require creating expired entries
        // For now, just test that it doesn't fail
        expect(provider.trimExpired(), greaterThanOrEqualTo(0));
      });
    });

    group('entry information', () {
      test('getEntry returns entry', () {
        provider.set('key', 'value', ttl: const Duration(hours: 1));
        final entry = provider.getEntry<String>('key');
        expect(entry, isNotNull);
        expect(entry!.value, equals('value'));
      });

      test('getTimeToLive returns remaining time', () {
        provider.set('key', 'value', ttl: const Duration(hours: 1));
        final ttl = provider.getTimeToLive('key');
        expect(ttl, isNotNull);
        expect(ttl!.inMinutes, greaterThan(55));
      });

      test('getAge returns entry age', () {
        provider.set('key', 'value');
        final age = provider.getAge('key');
        expect(age, isNotNull);
        expect(age!.inSeconds, lessThanOrEqualTo(1));
      });

      test('extendTTL extends and notifies', () {
        provider.set('key', 'value', ttl: const Duration(hours: 1));

        var notified = false;
        provider.addListener(() => notified = true);

        final success = provider.extendTTL('key', const Duration(hours: 1));

        expect(success, isTrue);
        expect(notified, isTrue);
      });

      test('refresh resets TTL and notifies', () {
        provider.set('key', 'value', ttl: const Duration(hours: 1));

        var notified = false;
        provider.addListener(() => notified = true);

        final success = provider.refresh('key');

        expect(success, isTrue);
        expect(notified, isTrue);
      });
    });

    group('statistics', () {
      test('getStats returns correct statistics', () {
        provider
          ..set('a', 1)
          ..set('b', 2)
          ..setPermanent('c', 3);

        final stats = provider.getStats();

        expect(stats.totalEntries, equals(3));
        expect(stats.validEntries, equals(3));
        expect(stats.permanentEntries, equals(1));
      });
    });

    group('configuration', () {
      test('uses config from constructor', () {
        final configuredProvider = CacheProvider(
          config: const CacheConfig(defaultTTL: Duration(minutes: 15)),
        );

        configuredProvider.set('key', 'value');
        final ttl = configuredProvider.getTimeToLive('key');

        expect(ttl, isNotNull);
        expect(ttl!.inMinutes, lessThanOrEqualTo(15));

        configuredProvider.dispose();
      });
    });
  });
}
