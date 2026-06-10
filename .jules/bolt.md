## 2026-06-03 - [Optimizing Daily Limit Checks]
**Learning:** Redundant joins to `transactions` when querying `ledger_entries` for limits or history is an anti-pattern. Since `ledger_entries` has its own `created_at` timestamp which is transactionally consistent with the parent transaction, we can filter directly on it. This, combined with a composite index on `(profile_id, created_at DESC)`, significantly reduces query execution time and lock contention.
**Action:** Always check if a join can be eliminated by using local columns in the ledger table for time-series filtering.
