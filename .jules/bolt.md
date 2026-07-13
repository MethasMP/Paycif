## 2026-07-13 - Atomic Idempotency and String Optimization
**Learning:** Using `INSERT ... ON CONFLICT (reference_id) DO NOTHING` and checking `RowsAffected()` is significantly more efficient than a separate `SELECT EXISTS` check, as it reduces database roundtrips. Manual JSON construction with `strconv` provides performance gains in benchmarks but may be rejected in code reviews in favor of maintainability (`fmt.Sprintf` or `encoding/json`).
**Action:** Prioritize atomic database operations for idempotency. Use string concatenation for simple keys/descriptions where readability is preserved, but stick to standard JSON tools unless extreme performance is required.

## 2026-07-13 - CI Hygiene and Linter Filtering
**Learning:** When dealing with a codebase containing legacy linting issues, use `--new-from-rev=origin/main` in `golangci-lint` to isolate and verify only new changes. This requires `fetch-depth: 0` in `actions/checkout` and an explicit `git fetch origin main` to ensure the linter can compare against the base branch. Unused code (helpers, types) in modified files should be purged to avoid triggering the `unused` linter.
**Action:** Always configure CI with full git history and branch-relative filtering when working on existing modules with high tech debt.
