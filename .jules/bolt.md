# Bolt's Performance Journal

## 2026-06-12 - Redundant Join in Financial Limit Checks
**Learning:** Redundant joins to the `transactions` table when querying `ledger_entries` for limits or simple history is a common anti-pattern. Since `ledger_entries` already contains a `created_at` timestamp and a composite index on `(profile_id, created_at DESC)`, filtering directly on the ledger table is significantly faster and more scalable.
**Action:** Always check if a query on `ledger_entries` can be satisfied without joining `transactions`, especially for performance-critical paths like payout limit checks.

## 2026-06-12 - Idempotency Pattern in Serializable Transactions
**Learning:** In high-concurrency systems using `SERIALIZABLE` isolation, performing a `SELECT EXISTS` check before an `INSERT` increases the transaction duration and the probability of serialization conflicts.
**Action:** Use `INSERT ... ON CONFLICT (reference_id) DO NOTHING` to perform idempotent inserts in a single atomic step, reducing the transaction window.
