# Bolt's Journal - Critical Learnings Only

## 2026-07-05 - WalletService Optimizations Regression Pattern
**Learning:** Hot path optimizations in `WalletService` (like replacing `fmt.Sprintf` with string concatenation for cache keys and transaction descriptions) are frequently reverted or overwritten during feature refactors due to standard formatting defaults in automated tools.
**Action:** Always verify the actual state of `wallet_service.go` against established performance patterns, and restore string concatenation for `GetExchangeRate` cache keys and `PayoutToPromptPay` descriptions if they were reverted.

## 2026-07-08 - Atomic Idempotency via ON CONFLICT DO NOTHING
**Learning:** Pre-checking idempotency via `SELECT EXISTS` in SERIALIZABLE transactions creates redundant database roundtrips and increases transaction durations, which in turn elevates the probability of serialization failure under high concurrency. Using `INSERT ... ON CONFLICT (reference_id) DO NOTHING` and checking `RowsAffected()` solves this.
**Action:** Implement atomic idempotency patterns directly in the database write step where a unique constraint exists, rather than performing pre-flight query checks.
