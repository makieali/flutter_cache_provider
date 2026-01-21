/// Statistics about the current state of a cache.
///
/// Use [Cache.getStats()] to retrieve statistics about the cache.
///
/// Example:
/// ```dart
/// final stats = cache.getStats();
/// print('Valid entries: ${stats.validEntries}');
/// print('Expired entries: ${stats.expiredEntries}');
/// print('Average age: ${stats.averageAge}');
/// ```
class CacheStats {
  /// Creates a cache statistics object.
  const CacheStats({
    required this.totalEntries,
    required this.validEntries,
    required this.expiredEntries,
    required this.permanentEntries,
    required this.averageAge,
    this.oldestKey,
    this.newestKey,
  });

  /// Total number of entries (including expired).
  final int totalEntries;

  /// Number of valid (non-expired) entries.
  final int validEntries;

  /// Number of expired entries awaiting cleanup.
  final int expiredEntries;

  /// Number of permanent (never-expiring) entries.
  final int permanentEntries;

  /// Average age of valid entries.
  final Duration averageAge;

  /// The key of the least recently accessed entry.
  final String? oldestKey;

  /// The key of the most recently accessed entry.
  final String? newestKey;

  /// The percentage of entries that have expired.
  double get expirationRate {
    if (totalEntries == 0) return 0;
    return expiredEntries / totalEntries;
  }

  /// The percentage of entries that are permanent.
  double get permanentRate {
    if (validEntries == 0) return 0;
    return permanentEntries / validEntries;
  }

  /// Returns a formatted string representation of the stats.
  String get summary {
    final buffer = StringBuffer()
      ..writeln('Cache Statistics:')
      ..writeln('  Total entries: $totalEntries')
      ..writeln('  Valid entries: $validEntries')
      ..writeln('  Expired entries: $expiredEntries')
      ..writeln('  Permanent entries: $permanentEntries')
      ..writeln('  Average age: ${_formatDuration(averageAge)}')
      ..writeln('  Expiration rate: ${(expirationRate * 100).toStringAsFixed(1)}%');

    if (oldestKey != null) {
      buffer.writeln('  Oldest key: $oldestKey');
    }
    if (newestKey != null) {
      buffer.writeln('  Newest key: $newestKey');
    }

    return buffer.toString();
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Converts the statistics to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'totalEntries': totalEntries,
      'validEntries': validEntries,
      'expiredEntries': expiredEntries,
      'permanentEntries': permanentEntries,
      'averageAgeMs': averageAge.inMilliseconds,
      'expirationRate': expirationRate,
      'permanentRate': permanentRate,
      'oldestKey': oldestKey,
      'newestKey': newestKey,
    };
  }

  @override
  String toString() {
    return 'CacheStats('
        'totalEntries: $totalEntries, '
        'validEntries: $validEntries, '
        'expiredEntries: $expiredEntries, '
        'permanentEntries: $permanentEntries, '
        'averageAge: $averageAge)';
  }
}
