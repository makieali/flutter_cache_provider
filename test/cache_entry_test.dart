import 'package:flutter_cache_provider/flutter_cache_provider.dart';
import 'package:test/test.dart';

void main() {
  group('CacheEntry', () {
    group('creation', () {
      test('creates entry with value and default timestamp', () {
        final entry = CacheEntry<String>('test value');

        expect(entry.value, equals('test value'));
        expect(entry.createdAt, isNotNull);
        expect(
          entry.createdAt.difference(DateTime.now()).inSeconds.abs(),
          lessThan(1),
        );
      });

      test('creates entry with TTL', () {
        final entry = CacheEntry<int>(42, ttl: const Duration(minutes: 5));

        expect(entry.value, equals(42));
        expect(entry.expiresAt, isNotNull);
        expect(entry.isValid, isTrue);
      });

      test('creates entry with custom timestamp', () {
        final timestamp = DateTime(2024, 1, 1);
        final entry = CacheEntry<String>(
          'value',
          timestamp: timestamp,
          ttl: const Duration(hours: 1),
        );

        expect(entry.createdAt, equals(timestamp));
        expect(
          entry.expiresAt,
          equals(timestamp.add(const Duration(hours: 1))),
        );
      });

      test('creates permanent entry', () {
        final entry = CacheEntry<String>.permanent('permanent value');

        expect(entry.value, equals('permanent value'));
        expect(entry.expiresAt, isNull);
        expect(entry.isValid, isTrue);
      });
    });

    group('validity', () {
      test('entry without TTL is always valid', () {
        final entry = CacheEntry<String>('value');

        expect(entry.isValid, isTrue);
        expect(entry.isExpired, isFalse);
      });

      test('entry with future expiration is valid', () {
        final entry = CacheEntry<String>(
          'value',
          ttl: const Duration(hours: 1),
        );

        expect(entry.isValid, isTrue);
        expect(entry.isExpired, isFalse);
      });

      test('entry with past expiration is invalid', () {
        final entry = CacheEntry<String>(
          'value',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          ttl: const Duration(hours: 1),
        );

        expect(entry.isValid, isFalse);
        expect(entry.isExpired, isTrue);
      });
    });

    group('age and TTL', () {
      test('age returns time since creation', () {
        final pastTime = DateTime.now().subtract(const Duration(minutes: 5));
        final entry = CacheEntry<String>('value', timestamp: pastTime);

        expect(entry.age.inMinutes, greaterThanOrEqualTo(5));
      });

      test('timeToLive returns remaining time', () {
        final entry = CacheEntry<String>(
          'value',
          ttl: const Duration(hours: 1),
        );

        final ttl = entry.timeToLive!;
        expect(ttl.inMinutes, greaterThan(55));
        expect(ttl.inMinutes, lessThanOrEqualTo(60));
      });

      test('timeToLive returns null for permanent entry', () {
        final entry = CacheEntry<String>.permanent('value');

        expect(entry.timeToLive, isNull);
      });

      test('timeToLive returns zero for expired entry', () {
        final entry = CacheEntry<String>(
          'value',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          ttl: const Duration(hours: 1),
        );

        expect(entry.timeToLive, equals(Duration.zero));
      });
    });

    group('serialization', () {
      test('toJson and fromJson roundtrip', () {
        final original = CacheEntry<String>(
          'test value',
          ttl: const Duration(hours: 1),
        );

        final json = original.toJson();
        final restored = CacheEntry<String>.fromJson(
          json,
          (v) => v as String,
        );

        expect(restored.value, equals(original.value));
        expect(
          restored.createdAt.difference(original.createdAt).inSeconds.abs(),
          lessThan(1),
        );
      });

      test('toJson with custom converter', () {
        final entry = CacheEntry<DateTime>(DateTime(2024, 1, 15));

        final json = entry.toJson(
          (date) => date.toIso8601String(),
        );

        expect(json['value'], equals('2024-01-15T00:00:00.000'));
      });

      test('fromJson with custom converter', () {
        final json = {
          'value': '2024-01-15T00:00:00.000',
          'createdAt': DateTime.now().toIso8601String(),
        };

        final entry = CacheEntry<DateTime>.fromJson(
          json,
          (v) => DateTime.parse(v as String),
        );

        expect(entry.value, equals(DateTime(2024, 1, 15)));
      });
    });

    group('copyWith', () {
      test('creates copy with updated value', () {
        final original = CacheEntry<String>('original');
        final copy = original.copyWith(value: 'updated');

        expect(copy.value, equals('updated'));
        expect(copy.createdAt, equals(original.createdAt));
      });

      test('creates copy with updated timestamps', () {
        final original = CacheEntry<String>(
          'value',
          ttl: const Duration(hours: 1),
        );
        final newExpiry = DateTime.now().add(const Duration(hours: 2));
        final copy = original.copyWith(expiresAt: newExpiry);

        expect(copy.value, equals(original.value));
        expect(copy.expiresAt, equals(newExpiry));
      });
    });

    group('equality', () {
      test('equal entries are equal', () {
        final timestamp = DateTime.now();
        final entry1 = CacheEntry<String>(
          'value',
          timestamp: timestamp,
          ttl: const Duration(hours: 1),
        );
        final entry2 = CacheEntry<String>(
          'value',
          timestamp: timestamp,
          ttl: const Duration(hours: 1),
        );

        expect(entry1, equals(entry2));
        expect(entry1.hashCode, equals(entry2.hashCode));
      });

      test('different values are not equal', () {
        final timestamp = DateTime.now();
        final entry1 = CacheEntry<String>('value1', timestamp: timestamp);
        final entry2 = CacheEntry<String>('value2', timestamp: timestamp);

        expect(entry1, isNot(equals(entry2)));
      });
    });

    group('toString', () {
      test('returns descriptive string', () {
        final entry = CacheEntry<String>('test');
        final str = entry.toString();

        expect(str, contains('CacheEntry<String>'));
        expect(str, contains('test'));
        expect(str, contains('isValid: true'));
      });
    });
  });
}
