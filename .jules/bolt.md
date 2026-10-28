# Bolt's Journal

## 2026-10-28 - Hot-path RateLimiter Middleware Optimization
**Learning:** `fmt.Sprintf` reflection overhead in HTTP middleware hot paths creates high heap allocation pressure and latency spikes under load. In-memory counters using `sync.Mutex` suffer lock contention across concurrent requests.
**Action:** Always prefer direct string concatenation (`strconv.FormatInt`) for Redis/memory rate limiter cache keys and `sync/atomic` primitives for concurrent counters in high-throughput middleware.
