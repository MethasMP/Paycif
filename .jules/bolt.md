## 2026-06-11 - Database and Cache Optimization in WalletService

**Learning:** Redundant JOINs to the `transactions` table during limit checks can be avoided by filtering directly on `ledger_entries` if the necessary columns (like `created_at`) are present and indexed. Also, cache fragmentation occurs when input strings (like currency codes) are not normalized before being used as cache keys, leading to suboptimal hit rates.

**Action:** Always check if a JOIN can be eliminated by using indexed columns in the primary table. Normalize all lookup parameters (uppercase/lowercase/trim) before generating cache keys or performing database lookups.

## 2026-06-11 - Resolving golangci-lint Version Mismatch in CI

**Learning:** When a Go project targets a version (e.g., Go 1.26) higher than the version used to build the pre-compiled `golangci-lint` binary in CI, the linter will fail with a "Go language version used to build golangci-lint is lower than the targeted Go version" error.

**Action:** In `golangci-lint-action`, set `install-mode: go` and ensure the `actions/setup-go` version matches the project's target version. This forces the linter to be compiled with the correct Go runtime, ensuring compatibility.
