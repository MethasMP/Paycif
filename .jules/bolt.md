# Bolt's Performance Journal

## 2026-07-20 - Atomic Idempotency Pattern vs Read-Before-Write
**Learning:** Checking existence beforehand with a `SELECT EXISTS` query before performing an `INSERT` inside a `SERIALIZABLE` transaction introduces an extra roundtrip and often leads to serialization conflicts under high concurrency. Using `INSERT ... ON CONFLICT (reference_id) DO NOTHING` and checking `RowsAffected() == 0` achieves the exact same idempotency atomically in a single statement.
**Action:** Always favor atomic `ON CONFLICT DO NOTHING` idempotency over a separate read check in write transactions.

## 2026-07-20 - Hot Path String Formatting Overheads
**Learning:** Standard formatters like `fmt.Sprintf` are highly readable but introduce substantial reflection and allocation overhead. On hot paths like cache key lookup and payload generation, simple string concatenation and `strconv.FormatFloat` provide ~1.7x to 3.9x speedups and reduce allocations to zero.
**Action:** Use manual string concatenation on highly executed paths like cache key lookups.
