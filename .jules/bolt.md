## 2025-05-15 - [Database Round-trip Reduction in Serializable Transactions]
**Learning:** In high-concurrency systems using SERIALIZABLE isolation (like our Go backend), every extra round-trip inside a transaction increases the risk of serialization failures (40001). Replacing 'SELECT EXISTS' checks with atomic 'INSERT ... ON CONFLICT DO NOTHING' reduces the transaction window significantly.
**Action:** Always prefer atomic UPSERT or 'ON CONFLICT' patterns over 'Check-then-Act' for idempotency and status updates in Go services.

## 2025-05-15 - [FX Cache Key Consistency]
**Learning:** Inconsistent casing in currency codes (USD vs usd) leads to cache fragmentation and redundant database/API lookups in the FX service.
**Action:** Always normalize string identifiers (currency codes, user IDs, keys) to a consistent casing (usually uppercase) at the earliest possible entry point before they are used as cache keys or DB query parameters.
