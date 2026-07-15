# Bolt's Performance Journal

## 2026-07-14 - WalletService Performance Regression
**Learning:** Establishing that critical performance optimizations (atomic idempotency, string concatenation) in `WalletService` are prone to being reverted during refactors. Also discovered that non-standard error checking like `errors.AsType` was being used, which can break retry logic for serializable transactions.
**Action:** Always verify the state of `wallet_service.go` against established patterns (ON CONFLICT, concatenation) before starting new work. Use standard `errors.As` for all Postgres error checks to ensure reliability.
