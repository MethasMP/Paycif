# Bolt's Performance Journal ⚡

## 2026-06-24 - Hot Path Regression and Atomic Idempotency
**Learning:** Found that critical optimizations in `WalletService` had regressed or were missing. Hot paths like `GetExchangeRate` were using `fmt.Sprintf` for cache keys, and `ProcessPayment` was using a two-step "select-then-insert" pattern which is inefficient under `SERIALIZABLE` isolation.
**Action:** Always prefer `INSERT ... ON CONFLICT DO NOTHING` for idempotency to reduce DB round-trips. Use string concatenation instead of `fmt.Sprintf` in high-frequency paths (Go's `fmt` uses reflection). Maintain a `_perf_test.go` file to detect these regressions.
