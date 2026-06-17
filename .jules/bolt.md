## 2026-06-16 - Atomic Idempotency in High-Concurrency Transactions
**Learning:** Collapsing "check-then-insert" into an atomic `INSERT ... ON CONFLICT DO NOTHING` is critical for systems using `SERIALIZABLE` isolation. It reduces the window for serialization conflicts and saves a database round-trip.
**Action:** Always prefer atomic UPSERT/Conflict handling over separate SELECT/INSERT blocks for idempotency in performance-critical paths.

## 2026-06-16 - DB Interaction Testing with sqlmock
**Learning:** `github.com/DATA-DOG/go-sqlmock` is the preferred tool for unit testing complex database interactions in the Go backend without requiring a live Postgres instance, allowing for precise verification of SQL execution flow.
**Action:** Use `go-sqlmock` for verifying performance optimizations that involve changes to SQL execution flow (e.g., number of queries, specific statement types).
