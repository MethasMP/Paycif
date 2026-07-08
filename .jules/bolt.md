## 2026-07-06 - [WalletService Optimization]
**Learning:** Replacing redundant `SELECT EXISTS` before `INSERT` with `INSERT ... ON CONFLICT DO NOTHING` and checking `RowsAffected()` eliminates a database roundtrip and provides atomic idempotency.
**Action:** Always prefer atomic idempotency patterns in high-concurrency database operations.

**Learning:** `fmt.Sprintf` is significantly slower than string concatenation for simple string formatting in hot paths. `strconv.Quote()` provides a safe way to escape strings when manually constructing JSON, preventing injection while maintaining performance.
**Action:** Use string concatenation for hot-path cache keys and `strconv` for manual JSON construction in performance-critical sections.

## 2026-07-06 - [CI Fix for Go 1.26]
**Learning:** When using a very new or custom Go version (like 1.26.4), pre-built `golangci-lint` binaries might be incompatible if they were built with an older Go version.
**Action:** Use `install-mode: goinstall` in `golangci-lint-action` to ensure the linter is built with the project's Go version, avoiding "can't load config" errors.
