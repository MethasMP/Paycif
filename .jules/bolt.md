## 2026-06-11 - Redundant Idempotency Round-trips
**Learning:** Performing a `SELECT EXISTS` before an `INSERT` for idempotency creates an unnecessary database round-trip. In high-concurrency systems, this increases the transaction duration and the probability of serialization failures (under SERIALIZABLE isolation).
**Action:** Consolidate into a single `INSERT ... ON CONFLICT (reference_id) DO NOTHING` and use `Result.RowsAffected()` to determine if the record was skipped. This reduces RTT by 50% for the idempotency check portion of the transaction.
