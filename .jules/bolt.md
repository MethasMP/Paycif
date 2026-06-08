## 2026-06-11 - [WalletService Optimizations: Idempotency, Redundant Joins, and Cache Normalization]

**Learning:**
1. Redundant joins to `transactions` when querying `ledger_entries` for limits is an anti-pattern. Since `ledger_entries` records are created within the same transaction as their parent transaction, they share the same `created_at` timestamp. Filtering directly on `ledger_entries.created_at` leverages the `idx_ledger_entries_profile_created` composite index, avoiding the overhead of a join.
2. In high-concurrency systems using `SERIALIZABLE` isolation, separate `SELECT EXISTS` checks followed by `INSERT` increase the probability of serialization conflicts and add unnecessary network round-trips. Using `INSERT ... ON CONFLICT DO NOTHING` atomizes the operation and reduces RTT from 2 to 1.
3. Lack of input normalization before caching (e.g., currency codes) leads to cache fragmentation and lower hit rates. Normalizing to uppercase before cache key generation ensures consistency.

**Action:**
1. Always check if a join can be avoided by using columns already present in the primary table being queried, especially when composite indexes are available.
2. Prefer atomic database operations (`ON CONFLICT`, `UPSERT`) over read-then-write patterns to minimize RTT and concurrency issues.
3. Implement input normalization at the beginning of service methods that use caching or specific database lookups.
