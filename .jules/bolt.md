## 2025-05-26 - [Transaction Roundtrip Optimization]
**Learning:** In high-concurrency financial systems using SERIALIZABLE isolation, every database roundtrip within a transaction increases the "critical section" duration. This not only adds network latency but also significantly increases the probability of serialization conflicts (deadlocks or 40001 errors). Batching independent inserts (like dual-entry ledger lines) and removing redundant read-after-write integrity checks can reduce transaction time and improve overall system throughput.

**Action:** Always look for opportunities to batch SQL statements in critical paths. Use multi-row `INSERT` and avoid `SELECT` queries that merely verify what you just wrote if the transaction is atomic.
