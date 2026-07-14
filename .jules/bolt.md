## 2026-07-14 - Atomic Idempotency and Hot-Path String Concatenation
**Learning:** Replacing a two-step 'SELECT EXISTS' and 'INSERT' pattern with 'INSERT ... ON CONFLICT DO NOTHING' and checking 'RowsAffected()' reduces database round-trips. Using string concatenation for small, frequent keys is ~3.6x faster than 'fmt.Sprintf'.
**Action:** Always favor atomic SQL operations for idempotency and avoid the 'fmt' package for simple string building in hot paths (like cache keys).
