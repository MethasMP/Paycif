# Bolt's Performance Journal

## 2026-07-06 - [Optimization] Atomic Idempotency in WalletService
**Learning:** Replacing a `SELECT EXISTS` followed by an `INSERT` with a single `INSERT ... ON CONFLICT DO NOTHING` reduces database roundtrips and transaction duration, which is critical for SERIALIZABLE isolation levels to avoid serialization failures.
**Action:** Use `INSERT ... ON CONFLICT DO NOTHING` and check `RowsAffected()` for atomic idempotency in all hot-path transaction logic.

## 2026-07-06 - [Environment] Testing in Go Workspaces
**Learning:** Running `go test` within a module subdirectory of a workspace can fail due to module resolution issues if `go.work` is present at the root.
**Action:** Use `GOWORK=off` when running tests or linters on a specific module to ensure consistent dependency resolution.

## 2026-07-06 - [Security/Maintainability] Prioritize json.Marshal
**Learning:** Manual JSON construction with `fmt.Sprintf` is unsafe and brittle. `json.Marshal` provides correctness and safety at a minor performance cost that is usually negligible compared to database roundtrips.
**Action:** Always use `json.Marshal` for JSON payloads unless benchmarks prove a critical bottleneck.
