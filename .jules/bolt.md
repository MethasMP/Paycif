## 2026-06-11 - Optimized ProcessPayment Idempotency Check
**Learning:** Collapsing a check-then-insert pattern into an atomic `INSERT ... ON CONFLICT DO NOTHING` reduces database round-trips from 2 to 1. This is especially beneficial in high-concurrency environments using `SERIALIZABLE` isolation, as it also reduces the window for serialization conflicts.
**Action:** Always look for "Check-Then-Act" patterns in database transactions and replace them with atomic SQL statements where possible.
