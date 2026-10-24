# Bolt's Journal - Critical Learnings

## 2026-10-24 - Rate Limiter Atomic Counter & Key Formatting
**Learning:** In Go, replacing `fmt.Sprintf("rate:%s:%d", identifier, minute)` with direct string concatenation `strconv.FormatInt` and replacing `SafeCounter`'s `sync.Mutex` lock with `atomic.AddInt64` drastically improves throughput and eliminates lock contention in high-throughput HTTP rate limiter middleware on hot request paths.
**Action:** Use atomic operations and direct string formatting in middleware or hot loops instead of `sync.Mutex` and `fmt.Sprintf`.
