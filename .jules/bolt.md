# Bolt's Journal - Critical Learnings

## 2026-10-02 - RateLimiterMiddleware Hot Path String Formatting & Atomic Counter
**Learning:** Using `fmt.Sprintf` for key construction in middleware allocated unnecessary memory and added string parsing overhead on every HTTP request. Furthermore, mutex locks on `SafeCounter` created lock contention under high concurrent load. Using direct string concatenation with `strconv.FormatInt` and lock-free `atomic.AddInt64` eliminates mutex contention and reduces heap allocations.
**Action:** Prefer string concatenation + `strconv` and lock-free atomic operations on hot HTTP request paths and high-concurrency rate limiters.
