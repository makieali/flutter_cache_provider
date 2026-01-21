import 'package:flutter_cache_provider/flutter_cache_provider.dart';
import 'package:test/test.dart';

void main() {
  group('CacheConfig', () {
    group('constructors', () {
      test('default constructor has sensible defaults', () {
        const config = CacheConfig();

        expect(config.defaultTTL, equals(const Duration(hours: 1)));
        expect(config.maxEntries, isNull);
        expect(config.enableAutoTrim, isFalse);
        expect(config.autoTrimInterval, equals(const Duration(minutes: 5)));
        expect(config.onEvicted, isNull);
      });

      test('permanent factory creates config with no TTL', () {
        const config = CacheConfig.permanent();

        expect(config.defaultTTL, isNull);
        expect(config.enableAutoTrim, isFalse);
      });

      test('shortLived factory creates config with 5 minute TTL', () {
        const config = CacheConfig.shortLived();

        expect(config.defaultTTL, equals(const Duration(minutes: 5)));
        expect(config.enableAutoTrim, isTrue);
        expect(config.autoTrimInterval, equals(const Duration(minutes: 1)));
      });

      test('longLived factory creates config with 24 hour TTL', () {
        const config = CacheConfig.longLived();

        expect(config.defaultTTL, equals(const Duration(hours: 24)));
        expect(config.enableAutoTrim, isTrue);
        expect(config.autoTrimInterval, equals(const Duration(hours: 1)));
      });
    });

    group('custom configuration', () {
      test('accepts custom defaultTTL', () {
        const config = CacheConfig(defaultTTL: Duration(minutes: 30));
        expect(config.defaultTTL, equals(const Duration(minutes: 30)));
      });

      test('accepts custom maxEntries', () {
        const config = CacheConfig(maxEntries: 100);
        expect(config.maxEntries, equals(100));
      });

      test('accepts enableAutoTrim', () {
        const config = CacheConfig(enableAutoTrim: true);
        expect(config.enableAutoTrim, isTrue);
      });

      test('accepts custom autoTrimInterval', () {
        const config = CacheConfig(
          enableAutoTrim: true,
          autoTrimInterval: Duration(seconds: 30),
        );
        expect(config.autoTrimInterval, equals(const Duration(seconds: 30)));
      });

      test('accepts onEvicted callback', () {
        var called = false;
        final config = CacheConfig(
          onEvicted: (key, value) => called = true,
        );

        config.onEvicted?.call('test', 'value');
        expect(called, isTrue);
      });
    });

    group('copyWith', () {
      test('creates copy with updated defaultTTL', () {
        const original = CacheConfig(defaultTTL: Duration(hours: 1));
        final copy = original.copyWith(defaultTTL: const Duration(hours: 2));

        expect(copy.defaultTTL, equals(const Duration(hours: 2)));
        expect(original.defaultTTL, equals(const Duration(hours: 1)));
      });

      test('creates copy with updated maxEntries', () {
        const original = CacheConfig(maxEntries: 100);
        final copy = original.copyWith(maxEntries: 200);

        expect(copy.maxEntries, equals(200));
        expect(original.maxEntries, equals(100));
      });

      test('creates copy with updated enableAutoTrim', () {
        const original = CacheConfig(enableAutoTrim: false);
        final copy = original.copyWith(enableAutoTrim: true);

        expect(copy.enableAutoTrim, isTrue);
        expect(original.enableAutoTrim, isFalse);
      });

      test('preserves unmodified fields', () {
        const original = CacheConfig(
          defaultTTL: Duration(hours: 1),
          maxEntries: 100,
          enableAutoTrim: true,
        );
        final copy = original.copyWith(maxEntries: 200);

        expect(copy.defaultTTL, equals(const Duration(hours: 1)));
        expect(copy.maxEntries, equals(200));
        expect(copy.enableAutoTrim, isTrue);
      });
    });

    group('toString', () {
      test('returns descriptive string', () {
        const config = CacheConfig(
          defaultTTL: Duration(hours: 1),
          maxEntries: 100,
        );

        final str = config.toString();

        expect(str, contains('CacheConfig'));
        expect(str, contains('defaultTTL'));
        expect(str, contains('maxEntries'));
      });
    });
  });

  group('CacheStats', () {
    test('expirationRate calculates correctly', () {
      const stats = CacheStats(
        totalEntries: 10,
        validEntries: 8,
        expiredEntries: 2,
        permanentEntries: 3,
        averageAge: Duration(minutes: 10),
      );

      expect(stats.expirationRate, equals(0.2));
    });

    test('expirationRate returns 0 for empty cache', () {
      const stats = CacheStats(
        totalEntries: 0,
        validEntries: 0,
        expiredEntries: 0,
        permanentEntries: 0,
        averageAge: Duration.zero,
      );

      expect(stats.expirationRate, equals(0));
    });

    test('permanentRate calculates correctly', () {
      const stats = CacheStats(
        totalEntries: 10,
        validEntries: 8,
        expiredEntries: 2,
        permanentEntries: 4,
        averageAge: Duration(minutes: 10),
      );

      expect(stats.permanentRate, equals(0.5));
    });

    test('permanentRate returns 0 for no valid entries', () {
      const stats = CacheStats(
        totalEntries: 2,
        validEntries: 0,
        expiredEntries: 2,
        permanentEntries: 0,
        averageAge: Duration.zero,
      );

      expect(stats.permanentRate, equals(0));
    });

    test('summary returns formatted string', () {
      const stats = CacheStats(
        totalEntries: 10,
        validEntries: 8,
        expiredEntries: 2,
        permanentEntries: 3,
        averageAge: Duration(minutes: 10),
        oldestKey: 'oldest',
        newestKey: 'newest',
      );

      final summary = stats.summary;

      expect(summary, contains('Cache Statistics'));
      expect(summary, contains('Total entries: 10'));
      expect(summary, contains('Valid entries: 8'));
      expect(summary, contains('Expired entries: 2'));
      expect(summary, contains('Permanent entries: 3'));
      expect(summary, contains('Oldest key: oldest'));
      expect(summary, contains('Newest key: newest'));
    });

    test('toJson returns correct map', () {
      const stats = CacheStats(
        totalEntries: 10,
        validEntries: 8,
        expiredEntries: 2,
        permanentEntries: 3,
        averageAge: Duration(minutes: 10),
        oldestKey: 'oldest',
        newestKey: 'newest',
      );

      final json = stats.toJson();

      expect(json['totalEntries'], equals(10));
      expect(json['validEntries'], equals(8));
      expect(json['expiredEntries'], equals(2));
      expect(json['permanentEntries'], equals(3));
      expect(json['averageAgeMs'], equals(600000));
      expect(json['oldestKey'], equals('oldest'));
      expect(json['newestKey'], equals('newest'));
    });

    test('toString returns descriptive string', () {
      const stats = CacheStats(
        totalEntries: 10,
        validEntries: 8,
        expiredEntries: 2,
        permanentEntries: 3,
        averageAge: Duration(minutes: 10),
      );

      final str = stats.toString();

      expect(str, contains('CacheStats'));
      expect(str, contains('totalEntries: 10'));
      expect(str, contains('validEntries: 8'));
    });
  });
}
