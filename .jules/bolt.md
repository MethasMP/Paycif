## 2025-05-27 - [Removing Post-Insert Integrity Check in Serializable Transactions]
**Learning:** In high-concurrency financial systems using `SERIALIZABLE` isolation, every additional `SELECT` within a transaction significantly increases the window for serialization conflicts (40001 errors in Postgres). The post-insert `SUM(amount)` integrity check, while conceptually sound, was redundant because the logic already ensured balance.
**Action:** Remove redundant reads in atomic transactions to decrease duration and conflict rate.

## 2025-05-27 - [Indexing for Financial Hot Paths]
**Learning:** Queries on `ledger_entries` (history) and `transactions` (limit checks) were missing composite indexes on `(wallet_id, created_at DESC)` and `(created_at DESC)`. This leads to sequential scans as the table grows, which is particularly expensive for system-wide limit checks that run on every transfer.
**Action:** Ensure all fields used in `WHERE` and `ORDER BY` for frequent queries are indexed.
