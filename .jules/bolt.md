## 2026-06-12 - Cache Fragmentation in GetExchangeRate
**Learning:** Normalizing inputs at the entry point of a cached function is critical. In `GetExchangeRate`, using `fromCurr` and `toCurr` directly in the cache key without normalization (e.g., to uppercase) led to cache fragmentation, where 'usd' and 'USD' would result in duplicate cache entries and redundant database lookups.
**Action:** Always normalize lookup keys (like currency codes or usernames) to a canonical casing before generating cache keys or querying the database.

## 2026-06-12 - Sprintf vs String Concatenation for Key Generation
**Learning:** Benchmarking confirmed that string concatenation is ~4x faster than `fmt.Sprintf` for simple key generation in Go (36ns vs 142ns/op). While often considered a micro-optimization, in high-throughput hot paths like cache lookups, this reduces CPU overhead and garbage collection pressure.
**Action:** Use string concatenation instead of `fmt.Sprintf` when building simple keys or small strings in hot code paths.
