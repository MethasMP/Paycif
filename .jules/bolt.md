## 2026-07-06 - [WalletService Optimization]
**Learning:** Replacing redundant `SELECT EXISTS` before `INSERT` with `INSERT ... ON CONFLICT DO NOTHING` and checking `RowsAffected()` eliminates a database roundtrip and provides atomic idempotency.
**Action:** Always prefer atomic idempotency patterns in high-concurrency database operations.

**Learning:** `fmt.Sprintf` is significantly slower than string concatenation for simple string formatting in hot paths. `strconv.Quote()` provides a safe way to escape strings when manually constructing JSON, preventing injection while maintaining performance.
**Action:** Use string concatenation for hot-path cache keys and `strconv` for manual JSON construction in performance-critical sections.
