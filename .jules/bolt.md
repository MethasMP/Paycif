## 2026-06-11 - [Optimization] Eliminate Redundant Joins in Limit Checks

**Learning:** In financial systems using double-entry bookkeeping, the `ledger_entries` table often contains all necessary metadata for balance and limit checks (profile_id, amount, created_at). Joining with a `transactions` table just to get a timestamp is a performance anti-pattern that bypasses composite indexes on the ledger table.

**Action:** Always check if the `ledger_entries` table has the required timestamp or profile mapping before joining with `transactions` for limit enforcement or balance calculations.

## 2026-06-11 - [Anti-pattern] Redundant Read before Insert for Idempotency

**Learning:** Using a separate `SELECT EXISTS` before an `INSERT` inside a `SERIALIZABLE` transaction increases the probability of serialization conflicts and adds an unnecessary network round-trip.

**Action:** Use `INSERT INTO ... ON CONFLICT (reference_id) DO NOTHING` and check rows affected or return the ID to handle idempotency in a single atomic database operation.
