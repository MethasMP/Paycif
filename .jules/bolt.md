# Bolt's Journal ⚡

Critical learnings about performance optimizations in this repository.

## 2026-10-10 - Rate Limiter Atomic Counter & Key Construction
**Learning:** In Go, replacing `fmt.Sprintf("rate:%s:%d", identifier, currentMinute)` with `strconv.FormatInt(currentMinute, 10)` and direct string concatenation reduces heap allocations and string formatting overhead on every incoming HTTP request. Switching `SafeCounter` from `sync.Mutex` to lock-free `sync/atomic` (`atomic.AddInt64`) removes mutex contention overhead under high concurrent request volume.
**Action:** Use lock-free atomic operations and `strconv` concatenation for hot-path middleware and cache keys.
