# Bolt's Performance Journal

## 2026-07-22 - Preventing Regressions in Hot-Path Cache Keys & Idempotency Check Pattern
**Learning:** Hot-path performance improvements (e.g., string concatenation for cache keys and consolidated `ON CONFLICT DO NOTHING` atomic idempotency queries) are frequently reverted during broad refactorings to less-efficient standard library patterns (like `fmt.Sprintf` or separate `SELECT EXISTS` checks).
**Action:** Always verify the active state of `wallet_service.go` against documented optimizations, and maintain a lightweight performance benchmark suite (`bolt_perf_test.go`) in the repository to continuously guard against formatting and SQL round-trip performance regressions.
