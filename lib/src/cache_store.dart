import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cache_provider/src/cache_entry.dart';

/// Abstract interface for cache persistence.
///
/// Implement this interface to create custom storage backends
/// for the cache (file system, SQLite, Hive, etc.).
///
/// Example implementation:
/// ```dart
/// class MyCustomStore implements CacheStore {
///   @override
///   Future<void> put(String key, CacheEntry entry) async {
///     // Store entry in your backend
///   }
///   // ... other methods
/// }
/// ```
abstract class CacheStore {
  /// Stores an entry in the persistent store.
  Future<void> put(String key, CacheEntry<dynamic> entry);

  /// Retrieves an entry from the persistent store.
  ///
  /// Returns null if the entry doesn't exist.
  Future<CacheEntry<dynamic>?> get(String key);

  /// Removes an entry from the persistent store.
  Future<void> remove(String key);

  /// Returns all keys in the persistent store.
  Future<List<String>> keys();

  /// Checks if a key exists in the persistent store.
  Future<bool> containsKey(String key);

  /// Clears all entries from the persistent store.
  Future<void> clear();

  /// Returns the number of entries in the store.
  Future<int> get length;

  /// Closes the store and releases any resources.
  Future<void> close();
}

/// In-memory cache store for testing or as L1 cache.
class MemoryCacheStore implements CacheStore {
  final Map<String, CacheEntry<dynamic>> _store = {};

  @override
  Future<void> put(String key, CacheEntry<dynamic> entry) async {
    _store[key] = entry;
  }

  @override
  Future<CacheEntry<dynamic>?> get(String key) async {
    return _store[key];
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }

  @override
  Future<List<String>> keys() async {
    return _store.keys.toList();
  }

  @override
  Future<bool> containsKey(String key) async {
    return _store.containsKey(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<int> get length async => _store.length;

  @override
  Future<void> close() async {
    // Nothing to close for memory store
  }
}

/// File-based cache store for persistent storage.
///
/// Stores each cache entry as a JSON file in the specified directory.
/// Suitable for small to medium caches where simplicity is preferred.
///
/// Example:
/// ```dart
/// final store = FileCacheStore(
///   directory: Directory('/path/to/cache'),
/// );
/// ```
class FileCacheStore implements CacheStore {
  /// Creates a file-based cache store.
  ///
  /// The [directory] will be created if it doesn't exist.
  FileCacheStore({
    required this.directory,
    this.fileExtension = '.cache',
  });

  /// The directory where cache files are stored.
  final Directory directory;

  /// File extension for cache files.
  final String fileExtension;

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _initialized = true;
  }

  String _keyToFileName(String key) {
    // Encode key to be file-system safe
    final encoded = base64Url.encode(utf8.encode(key));
    return '$encoded$fileExtension';
  }

  String _fileNameToKey(String fileName) {
    final encoded = fileName.replaceAll(fileExtension, '');
    return utf8.decode(base64Url.decode(encoded));
  }

  File _getFile(String key) {
    return File('${directory.path}/${_keyToFileName(key)}');
  }

  @override
  Future<void> put(String key, CacheEntry<dynamic> entry) async {
    await _ensureInitialized();
    final file = _getFile(key);
    final json = jsonEncode({
      'value': entry.value,
      'createdAt': entry.createdAt.toIso8601String(),
      'expiresAt': entry.expiresAt?.toIso8601String(),
    });
    await file.writeAsString(json);
  }

  @override
  Future<CacheEntry<dynamic>?> get(String key) async {
    await _ensureInitialized();
    final file = _getFile(key);
    if (!await file.exists()) return null;

    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final expiresAtStr = json['expiresAt'] as String?;
      final createdAt = DateTime.parse(json['createdAt'] as String);
      final expiresAt =
          expiresAtStr != null ? DateTime.parse(expiresAtStr) : null;

      // Calculate TTL from timestamps
      final ttl = expiresAt?.difference(createdAt);

      return CacheEntry<dynamic>(
        json['value'],
        timestamp: createdAt,
        ttl: ttl,
      );
    } catch (e) {
      // Corrupted cache file, remove it
      await file.delete();
      return null;
    }
  }

  @override
  Future<void> remove(String key) async {
    await _ensureInitialized();
    final file = _getFile(key);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<List<String>> keys() async {
    await _ensureInitialized();
    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith(fileExtension))
        .map((entity) => _fileNameToKey(entity.uri.pathSegments.last))
        .toList();
    return files;
  }

  @override
  Future<bool> containsKey(String key) async {
    await _ensureInitialized();
    return _getFile(key).exists();
  }

  @override
  Future<void> clear() async {
    await _ensureInitialized();
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith(fileExtension)) {
        await entity.delete();
      }
    }
  }

  @override
  Future<int> get length async {
    await _ensureInitialized();
    var count = 0;
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith(fileExtension)) {
        count++;
      }
    }
    return count;
  }

  @override
  Future<void> close() async {
    // Nothing to close for file store
  }
}

/// Serialization helper for cache entries.
///
/// Use this to serialize complex objects for persistent storage.
abstract class CacheSerializer<T> {
  /// Serializes a value to a JSON-compatible format.
  dynamic serialize(T value);

  /// Deserializes a value from JSON.
  T deserialize(dynamic json);
}

/// Default serializer that works with JSON-compatible types.
class JsonCacheSerializer<T> implements CacheSerializer<T> {
  @override
  dynamic serialize(T value) => value;

  @override
  T deserialize(dynamic json) => json as T;
}
