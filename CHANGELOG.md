## 1.0.1

### Documentation

- Shortened package description for pub.dev compliance
- Added example file for pub.dev scoring

## 1.0.0

### Initial Release

A production-ready, enterprise-grade caching solution for Flutter and Dart.

#### Core Features
- Type-safe generic caching with TTL support
- Hierarchical (path-based) key organization
- Flutter Provider integration (ChangeNotifier)
- Configurable auto-trim for expired entries

#### Advanced Features
- **LoadingCache**: Caffeine-style auto-loading cache with in-flight request deduplication
- **TieredCache**: L1 (in-memory) + L2 (persistent) architecture with automatic promotion
- **Stale-While-Revalidate**: Return stale data immediately while refreshing in background
- **Cache Warming**: Bulk pre-loading with sync and async support

#### Eviction Policies
- LRU (Least Recently Used) - default
- LFU (Least Frequently Used)
- FIFO (First In First Out)

#### Monitoring & Observability
- **CacheMetrics**: Hit/miss tracking with latency percentiles (P50, P95, P99)
- **Event Streams**: Reactive cache events (created, updated, removed, expired, evicted)
- **Prometheus Export**: Production-ready metrics format

#### Architecture
- **CacheBuilder**: Fluent builder API inspired by Caffeine
- **NamespacedCache**: Cache partitioning with isolated namespaces
- **CacheStore**: Persistence interface with built-in File and Memory implementations

#### Testing
- 118 comprehensive tests
- Zero external dependencies
