
## 2026-07-06 - [Atomic Idempotency for Performance]
**Learning:** Consolidating `SELECT EXISTS` and `INSERT` into a single `INSERT ... ON CONFLICT DO NOTHING` is a high-impact optimization for distributed systems, reducing database roundtrips and locking windows.
**Action:** Always prefer atomic upserts or `ON CONFLICT` for idempotency logic in hot paths.
