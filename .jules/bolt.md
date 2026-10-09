## 2026-10-09 - Lock-Free Atomic Counter Optimization in In-Memory Rate Limiter Middleware

**Learning:** Replacing `sync.Mutex` lock/unlock in high-concurrency memory counters (like `SafeCounter` in `RateLimiterMiddleware`) with `atomic.AddInt64` reduces execution time per operation from ~93.0 ns/op to ~24.8 ns/op (~3.75x speedup) with zero heap allocations under parallel lock contention. Furthermore, replacing `fmt.Sprintf` with direct string concatenation and `strconv.FormatInt` in rate limiter key generation reduces key formatting overhead from ~207.9 ns/op to ~179.6 ns/op.

**Action:** Prefer lock-free atomic primitive operations (`atomic.AddInt64`/`atomic.AddUint64`) over mutex locks for simple integer counters in hot HTTP request middleware paths.

## 2026-10-09 - Fix golangci-lint Exit Code 3 Error in CI Workflows with Go 1.26

**Learning:** When `golangci-lint` fails with exit code 3 (`can't load config: the Go language version (go1.24) used to build golangci-lint is lower than the targeted Go version (1.26.5)`), setting `install-mode: goinstall` and `only-new-issues: true` under `golangci-lint-action@v4` along with `fetch-depth: 0` under `actions/checkout@v4` forces `golangci-lint` to build using the active Go runtime (1.26.5), resolving the version mismatch.

**Action:** Configure `install-mode: goinstall` and `fetch-depth: 0` in GitHub Actions workflows targeting Go pre-releases or newer Go versions.
