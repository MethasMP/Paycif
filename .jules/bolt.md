# Bolt's Performance Journal

## 2026-07-06 - [Optimization] Atomic Idempotency in WalletService
**Learning:** Replacing a `SELECT EXISTS` followed by an `INSERT` with a single `INSERT ... ON CONFLICT DO NOTHING` reduces database roundtrips and transaction duration, which is critical for SERIALIZABLE isolation levels to avoid serialization failures.
**Action:** Use `INSERT ... ON CONFLICT DO NOTHING` and check `RowsAffected()` for atomic idempotency in all hot-path transaction logic.

## 2026-07-06 - [Optimization] String Formatting on Hot Paths
**Learning:** `fmt.Sprintf` is significantly slower (~3-4x) than string concatenation for simple keys and ~1.5x slower for small JSON payloads due to reflection.
**Action:** Use string concatenation and `strconv` for cache keys, transaction descriptions, and manual JSON construction in high-throughput services. Use `strconv.Quote` for safety when building JSON manually.

## 2026-07-06 - [Environment] Testing in Go Workspaces
**Learning:** Running `go test` within a module subdirectory of a workspace can fail due to module resolution issues if `go.work` is present at the root.
**Action:** Use `GOWORK=off` when running tests or linters on a specific module to ensure consistent dependency resolution.
