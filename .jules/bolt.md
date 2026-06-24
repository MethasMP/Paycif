## 2026-06-20 - [Go Cache Key Generation Optimization]
**Learning:** For simple string-based cache key generation in Go (e.g., `rate:USD:THB`), `fmt.Sprintf` is ~3.5x slower than direct string concatenation because `fmt.Sprintf` uses reflection.
**Action:** Use string concatenation for simple keys in performance-critical paths.

## 2026-06-20 - [Normalization for Cache Hit Rates]
**Learning:** Normalizing inputs (like currency codes) to a consistent case (uppercase) at the entry point of a function prevents cache fragmentation where 'usd' and 'USD' would otherwise create separate cache entries.
**Action:** Always normalize lookup keys before cache and database operations.
