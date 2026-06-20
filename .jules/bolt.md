## 2026-06-20 - [Cache Fragmentation & Key Generation Overhead]
**Learning:** `fmt.Sprintf` is significantly slower (~4x) than simple string concatenation for small key generation in Go. More importantly, inconsistent casing in input parameters (e.g., 'usd' vs 'USD') leads to cache fragmentation and redundant database hits.
**Action:** Always normalize string identifiers to a standard casing (usually uppercase) at the entry point of service methods and use string concatenation for generating cache keys in performance-critical paths.

## 2026-06-20 - [Atomic Idempotency in SERIALIZABLE Transactions]
**Learning:** The "check-then-insert" pattern is an anti-pattern in high-concurrency systems, especially under `SERIALIZABLE` isolation, as it increases the window for conflicts and doubles the database round-trips.
**Action:** Use `INSERT ... ON CONFLICT DO NOTHING` and check `RowsAffected()` to handle idempotency atomically in a single statement.
