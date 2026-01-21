import 'dart:collection';

/// Available cache eviction policies.
enum EvictionPolicyType {
  /// Least Recently Used - evicts entries that haven't been accessed recently.
  ///
  /// Best for: General purpose caching where recent access indicates relevance.
  lru,

  /// Least Frequently Used - evicts entries with the fewest accesses.
  ///
  /// Best for: Caches where some items are accessed much more than others.
  lfu,

  /// First In First Out - evicts the oldest entries first.
  ///
  /// Best for: Time-based data where older entries are less relevant.
  fifo,

  /// No automatic eviction - entries are only removed manually or by TTL.
  none,
}

/// Abstract interface for cache eviction policies.
abstract class EvictionPolicy {
  /// Creates an eviction policy of the specified type.
  factory EvictionPolicy(EvictionPolicyType type) {
    switch (type) {
      case EvictionPolicyType.lru:
        return LRUEvictionPolicy();
      case EvictionPolicyType.lfu:
        return LFUEvictionPolicy();
      case EvictionPolicyType.fifo:
        return FIFOEvictionPolicy();
      case EvictionPolicyType.none:
        return NoEvictionPolicy();
    }
  }

  /// The type of this eviction policy.
  EvictionPolicyType get type;

  /// Called when a key is accessed (get or set).
  void onAccess(String key);

  /// Called when a key is added to the cache.
  void onAdd(String key);

  /// Called when a key is removed from the cache.
  void onRemove(String key);

  /// Returns the next key to evict, or null if no eviction needed.
  String? getEvictionCandidate();

  /// Clears all tracking data.
  void clear();

  /// Returns the number of keys being tracked.
  int get size;
}

/// Least Recently Used eviction policy.
///
/// Evicts entries that haven't been accessed recently.
/// Uses a doubly-linked list for O(1) access and eviction.
class LRUEvictionPolicy implements EvictionPolicy {
  final LinkedHashSet<String> _accessOrder = LinkedHashSet<String>();

  @override
  EvictionPolicyType get type => EvictionPolicyType.lru;

  @override
  void onAccess(String key) {
    // Move to end (most recently used)
    _accessOrder.remove(key);
    _accessOrder.add(key);
  }

  @override
  void onAdd(String key) {
    _accessOrder.add(key);
  }

  @override
  void onRemove(String key) {
    _accessOrder.remove(key);
  }

  @override
  String? getEvictionCandidate() {
    if (_accessOrder.isEmpty) return null;
    return _accessOrder.first; // Least recently used
  }

  @override
  void clear() {
    _accessOrder.clear();
  }

  @override
  int get size => _accessOrder.length;
}

/// Least Frequently Used eviction policy.
///
/// Evicts entries with the fewest accesses.
/// Tracks access counts for each key.
class LFUEvictionPolicy implements EvictionPolicy {
  final Map<String, int> _accessCounts = {};
  final Map<int, LinkedHashSet<String>> _frequencyBuckets = {};
  int _minFrequency = 0;

  @override
  EvictionPolicyType get type => EvictionPolicyType.lfu;

  @override
  void onAccess(String key) {
    if (!_accessCounts.containsKey(key)) return;

    final oldFreq = _accessCounts[key]!;
    final newFreq = oldFreq + 1;
    _accessCounts[key] = newFreq;

    // Remove from old frequency bucket
    _frequencyBuckets[oldFreq]?.remove(key);
    if (_frequencyBuckets[oldFreq]?.isEmpty ?? true) {
      _frequencyBuckets.remove(oldFreq);
      if (_minFrequency == oldFreq) {
        _minFrequency = newFreq;
      }
    }

    // Add to new frequency bucket
    _frequencyBuckets.putIfAbsent(newFreq, LinkedHashSet.new);
    _frequencyBuckets[newFreq]!.add(key);
  }

  @override
  void onAdd(String key) {
    _accessCounts[key] = 1;
    _frequencyBuckets.putIfAbsent(1, LinkedHashSet.new);
    _frequencyBuckets[1]!.add(key);
    _minFrequency = 1;
  }

  @override
  void onRemove(String key) {
    final freq = _accessCounts.remove(key);
    if (freq != null) {
      _frequencyBuckets[freq]?.remove(key);
      if (_frequencyBuckets[freq]?.isEmpty ?? true) {
        _frequencyBuckets.remove(freq);
      }
    }
    _updateMinFrequency();
  }

  @override
  String? getEvictionCandidate() {
    if (_accessCounts.isEmpty) return null;

    final bucket = _frequencyBuckets[_minFrequency];
    if (bucket == null || bucket.isEmpty) {
      _updateMinFrequency();
      final updatedBucket = _frequencyBuckets[_minFrequency];
      if (updatedBucket == null || updatedBucket.isEmpty) return null;
      return updatedBucket.first;
    }
    return bucket.first; // Least frequently used (and oldest among ties)
  }

  void _updateMinFrequency() {
    if (_frequencyBuckets.isEmpty) {
      _minFrequency = 0;
      return;
    }
    _minFrequency =
        _frequencyBuckets.keys.reduce((a, b) => a < b ? a : b);
  }

  @override
  void clear() {
    _accessCounts.clear();
    _frequencyBuckets.clear();
    _minFrequency = 0;
  }

  @override
  int get size => _accessCounts.length;

  /// Returns the access count for a key.
  int getAccessCount(String key) => _accessCounts[key] ?? 0;
}

/// First In First Out eviction policy.
///
/// Evicts the oldest entries first, regardless of access patterns.
class FIFOEvictionPolicy implements EvictionPolicy {
  final Queue<String> _insertionOrder = Queue<String>();
  final Set<String> _keys = {};

  @override
  EvictionPolicyType get type => EvictionPolicyType.fifo;

  @override
  void onAccess(String key) {
    // FIFO ignores access patterns
  }

  @override
  void onAdd(String key) {
    if (!_keys.contains(key)) {
      _keys.add(key);
      _insertionOrder.add(key);
    }
  }

  @override
  void onRemove(String key) {
    _keys.remove(key);
    // Note: We don't remove from queue for efficiency
    // getEvictionCandidate handles stale entries
  }

  @override
  String? getEvictionCandidate() {
    // Skip stale entries (already removed)
    while (_insertionOrder.isNotEmpty) {
      final candidate = _insertionOrder.first;
      if (_keys.contains(candidate)) {
        return candidate;
      }
      _insertionOrder.removeFirst();
    }
    return null;
  }

  @override
  void clear() {
    _insertionOrder.clear();
    _keys.clear();
  }

  @override
  int get size => _keys.length;
}

/// No eviction policy - entries are never automatically evicted.
///
/// Use this when you want manual control over eviction
/// or rely solely on TTL for entry removal.
class NoEvictionPolicy implements EvictionPolicy {
  @override
  EvictionPolicyType get type => EvictionPolicyType.none;

  @override
  void onAccess(String key) {}

  @override
  void onAdd(String key) {}

  @override
  void onRemove(String key) {}

  @override
  String? getEvictionCandidate() => null;

  @override
  void clear() {}

  @override
  int get size => 0;
}
