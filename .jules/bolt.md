## 2026-07-16 - [WalletService Hot-Path Optimization]
**Learning:** In high-concurrency systems using `SERIALIZABLE` isolation, reducing transaction duration is critical to avoid serialization failures. Combining idempotency checks with the initial insert using `INSERT ... ON CONFLICT DO NOTHING` and checking `RowsAffected()` eliminates a database roundtrip and narrows the contention window. Additionally, `fmt.Sprintf` is a measurable bottleneck in hot paths (like cache key generation) compared to string concatenation.
**Action:** Always favor atomic idempotency patterns in PostgreSQL to reduce roundtrips. Use string concatenation instead of `fmt.Sprintf` for high-frequency string building in Go.

## 2026-07-16 - [Fixing Hallucinated Helpers]
**Learning:** Reverting or fixing 'hallucinated' non-standard library helpers (like `errors.AsType`) using standard library equivalents (`errors.As`) is essential for both performance (avoiding overhead of custom wrappers) and codebase maintainability.
**Action:** Use standard library `errors.As` for type-safe error checking in Go.
