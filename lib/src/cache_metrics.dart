import 'dart:collection';

/// Comprehensive cache metrics for monitoring and observability.
///
/// Tracks hits, misses, evictions, expirations, and latency data
/// to help optimize cache configuration and monitor health.
///
/// Example:
/// ```dart
/// final cache = Cache(config: CacheConfig(recordStats: true));
/// // ... use cache ...
/// final metrics = cache.metrics;
/// print('Hit ratio: ${metrics.hitRatio}');
/// print('Avg get latency: ${metrics.averageGetLatency}');
/// ```
class CacheMetrics {
  /// Creates a new metrics instance.
  CacheMetrics() : _enabled = true;

  /// Creates a disabled metrics instance that ignores all operations.
  ///
  /// Use this when metrics collection is disabled to avoid null checks.
  CacheMetrics.disabled() : _enabled = false;

  final bool _enabled;

  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _expirations = 0;
  int _puts = 0;
  int _removes = 0;

  Duration _totalGetLatency = Duration.zero;
  Duration _totalPutLatency = Duration.zero;

  final Queue<_LatencySample> _recentGetLatencies = Queue();
  final Queue<_LatencySample> _recentPutLatencies = Queue();

  static const int _maxLatencySamples = 1000;

  /// Total number of cache hits.
  int get hits => _hits;

  /// Total number of cache misses.
  int get misses => _misses;

  /// Total number of get operations (hits + misses).
  int get gets => _hits + _misses;

  /// Total number of put operations.
  int get puts => _puts;

  /// Total number of remove operations.
  int get removes => _removes;

  /// Total number of evictions due to capacity limits.
  int get evictions => _evictions;

  /// Total number of expirations due to TTL.
  int get expirations => _expirations;

  /// Cache hit ratio (0.0 to 1.0).
  ///
  /// Returns 0.0 if no get operations have been performed.
  double get hitRatio {
    final total = _hits + _misses;
    if (total == 0) return 0;
    return _hits / total;
  }

  /// Cache miss ratio (0.0 to 1.0).
  double get missRatio => 1 - hitRatio;

  /// Hit ratio as a percentage string (e.g., "85.5%").
  String get hitRatioPercent => '${(hitRatio * 100).toStringAsFixed(1)}%';

  /// Average latency for get operations.
  Duration get averageGetLatency {
    if (gets == 0) return Duration.zero;
    return Duration(microseconds: _totalGetLatency.inMicroseconds ~/ gets);
  }

  /// Average latency for put operations.
  Duration get averagePutLatency {
    if (_puts == 0) return Duration.zero;
    return Duration(microseconds: _totalPutLatency.inMicroseconds ~/ _puts);
  }

  /// P50 (median) get latency from recent samples.
  Duration get p50GetLatency => _percentileLatency(_recentGetLatencies, 0.50);

  /// P95 get latency from recent samples.
  Duration get p95GetLatency => _percentileLatency(_recentGetLatencies, 0.95);

  /// P99 get latency from recent samples.
  Duration get p99GetLatency => _percentileLatency(_recentGetLatencies, 0.99);

  /// Records a cache hit.
  void recordHit() {
    if (!_enabled) return;
    _hits++;
  }

  /// Records a cache miss.
  void recordMiss() {
    if (!_enabled) return;
    _misses++;
  }

  /// Records a get operation latency.
  void recordGetLatency(Duration latency) {
    if (!_enabled) return;
    _recordGetLatency(latency);
  }

  /// Records a put operation with the operation latency.
  void recordPut(Duration latency) {
    if (!_enabled) return;
    _puts++;
    _totalPutLatency += latency;
    _addLatencySample(_recentPutLatencies, latency);
  }

  /// Records a remove operation.
  void recordRemove() {
    if (!_enabled) return;
    _removes++;
  }

  /// Records an eviction due to capacity limits.
  void recordEviction() {
    if (!_enabled) return;
    _evictions++;
  }

  /// Records an expiration due to TTL.
  void recordExpiration() {
    if (!_enabled) return;
    _expirations++;
  }

  void _recordGetLatency(Duration latency) {
    _totalGetLatency += latency;
    _addLatencySample(_recentGetLatencies, latency);
  }

  void _addLatencySample(Queue<_LatencySample> queue, Duration latency) {
    queue.add(_LatencySample(DateTime.now(), latency));
    while (queue.length > _maxLatencySamples) {
      queue.removeFirst();
    }
  }

  Duration _percentileLatency(Queue<_LatencySample> samples, double percentile) {
    if (samples.isEmpty) return Duration.zero;

    final sorted = samples.map((s) => s.latency.inMicroseconds).toList()..sort();
    final index = ((sorted.length - 1) * percentile).round();
    return Duration(microseconds: sorted[index]);
  }

  /// Resets all metrics to zero.
  void reset() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    _expirations = 0;
    _puts = 0;
    _removes = 0;
    _totalGetLatency = Duration.zero;
    _totalPutLatency = Duration.zero;
    _recentGetLatencies.clear();
    _recentPutLatencies.clear();
  }

  /// Returns a snapshot of current metrics as a map.
  Map<String, dynamic> toJson() {
    return {
      'hits': _hits,
      'misses': _misses,
      'gets': gets,
      'puts': _puts,
      'removes': _removes,
      'evictions': _evictions,
      'expirations': _expirations,
      'hitRatio': hitRatio,
      'missRatio': missRatio,
      'averageGetLatencyMicros': averageGetLatency.inMicroseconds,
      'averagePutLatencyMicros': averagePutLatency.inMicroseconds,
      'p50GetLatencyMicros': p50GetLatency.inMicroseconds,
      'p95GetLatencyMicros': p95GetLatency.inMicroseconds,
      'p99GetLatencyMicros': p99GetLatency.inMicroseconds,
    };
  }

  /// Returns metrics in Prometheus exposition format.
  String toPrometheus({String prefix = 'cache'}) {
    final buffer = StringBuffer()
      ..writeln('# HELP ${prefix}_hits_total Total cache hits')
      ..writeln('# TYPE ${prefix}_hits_total counter')
      ..writeln('${prefix}_hits_total $_hits')
      ..writeln()
      ..writeln('# HELP ${prefix}_misses_total Total cache misses')
      ..writeln('# TYPE ${prefix}_misses_total counter')
      ..writeln('${prefix}_misses_total $_misses')
      ..writeln()
      ..writeln('# HELP ${prefix}_evictions_total Total cache evictions')
      ..writeln('# TYPE ${prefix}_evictions_total counter')
      ..writeln('${prefix}_evictions_total $_evictions')
      ..writeln()
      ..writeln('# HELP ${prefix}_hit_ratio Cache hit ratio')
      ..writeln('# TYPE ${prefix}_hit_ratio gauge')
      ..writeln('${prefix}_hit_ratio $hitRatio')
      ..writeln()
      ..writeln('# HELP ${prefix}_get_latency_seconds Get operation latency')
      ..writeln('# TYPE ${prefix}_get_latency_seconds summary')
      ..writeln(
        '${prefix}_get_latency_seconds{quantile="0.5"} '
        '${p50GetLatency.inMicroseconds / 1000000}',
      )
      ..writeln(
        '${prefix}_get_latency_seconds{quantile="0.95"} '
        '${p95GetLatency.inMicroseconds / 1000000}',
      )
      ..writeln(
        '${prefix}_get_latency_seconds{quantile="0.99"} '
        '${p99GetLatency.inMicroseconds / 1000000}',
      );

    return buffer.toString();
  }

  /// Returns a human-readable summary of metrics.
  String get summary {
    final buffer = StringBuffer()
      ..writeln('Cache Metrics Summary')
      ..writeln('=====================')
      ..writeln('Operations:')
      ..writeln('  Gets: $gets (Hits: $_hits, Misses: $_misses)')
      ..writeln('  Puts: $_puts')
      ..writeln('  Removes: $_removes')
      ..writeln('  Evictions: $_evictions')
      ..writeln('  Expirations: $_expirations')
      ..writeln()
      ..writeln('Performance:')
      ..writeln('  Hit Ratio: $hitRatioPercent')
      ..writeln('  Avg Get Latency: ${_formatDuration(averageGetLatency)}')
      ..writeln('  P50 Get Latency: ${_formatDuration(p50GetLatency)}')
      ..writeln('  P95 Get Latency: ${_formatDuration(p95GetLatency)}')
      ..writeln('  P99 Get Latency: ${_formatDuration(p99GetLatency)}');

    return buffer.toString();
  }

  String _formatDuration(Duration duration) {
    if (duration.inMilliseconds > 1000) {
      return '${(duration.inMicroseconds / 1000000).toStringAsFixed(2)}s';
    } else if (duration.inMicroseconds > 1000) {
      return '${(duration.inMicroseconds / 1000).toStringAsFixed(2)}ms';
    } else {
      return '${duration.inMicroseconds}µs';
    }
  }

  @override
  String toString() {
    return 'CacheMetrics(hits: $_hits, misses: $_misses, '
        'hitRatio: $hitRatioPercent, evictions: $_evictions)';
  }
}

class _LatencySample {
  _LatencySample(this.timestamp, this.latency);
  final DateTime timestamp;
  final Duration latency;
}
