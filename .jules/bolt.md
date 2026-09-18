# Bolt's Journal

## 2026-09-18 - SafeCounter Atomic Optimization & Direct String Concatenation in RateLimiterMiddleware
**Learning:** `fmt.Sprintf` and `sync.Mutex` in `RateLimiterMiddleware` hot path add unnecessary lock contention and allocation overhead under high concurrent HTTP request load.
**Action:** Use lock-free `atomic.AddInt64` for counter increments and string concatenation + `strconv.FormatInt` for rate limiter key construction.
