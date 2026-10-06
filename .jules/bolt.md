# Bolt's Journal - Performance Insights

## 2026-10-06 - Hot Path Rate Limiter Optimization
**Learning:** `fmt.Sprintf` reflection/parsing adds ~2.5x runtime overhead and unnecessary heap allocations on high-throughput HTTP request rate-limiting paths. Furthermore, `sync.Mutex` lock contention under high concurrent load causes worker goroutines to block. Switching to direct string concatenation (`"rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)`) and lock-free atomic counter operations (`atomic.AddInt64`) drastically reduces allocation overhead and improves throughput.
**Action:** Always prefer direct string concatenation / `strconv` over `fmt.Sprintf` on per-request hot paths, and use lock-free atomic primitives for simple rate limiting or concurrent counters.
