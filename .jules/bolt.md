# Bolt's Performance Journal

## 2025-06-02 - [Database Optimization: Redundant Joins in Ledger Queries]
**Learning:** In high-frequency paths like limit checking, joining `ledger_entries` with `transactions` just to filter by time is an anti-pattern. `ledger_entries` already contains `created_at` and `profile_id`.
**Action:** Always filter directly on `ledger_entries` when possible. Ensure composite index exists on `(profile_id, created_at)` for optimal performance.
