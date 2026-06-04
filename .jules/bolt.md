## 2025-05-15 - [Avoid Redundant Joins for Limit Checks]
**Learning:** Joining with the `transactions` table to filter by `created_at` in daily limit checks is an anti-pattern. The `ledger_entries` table already contains a `created_at` column and a composite index on `(profile_id, created_at DESC)`.
**Action:** Always filter directly on `ledger_entries.created_at` when performing performance-critical balance or limit aggregations to leverage existing indexes and avoid the overhead of unnecessary joins.
