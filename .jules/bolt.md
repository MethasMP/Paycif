# Bolt's Performance Journal

## 2026-06-27 - Atomic Idempotency and String Optimization in Go

**Learning:**
1. `fmt.Sprintf` is a major bottleneck in Go's hot paths (like cache key generation and JSON construction) due to reflection. Manual concatenation is ~3.7x to 4x faster.
2. Using `strconv.Quote()` for JSON construction is not only faster than `fmt.Sprintf` but also safer as it handles escaping correctly.
3. Merging `SELECT EXISTS` and `INSERT` into an atomic `INSERT ... ON CONFLICT DO NOTHING` reduces database round-trips and improves performance under SERIALIZABLE isolation by reducing the transaction duration and the probability of serialization conflicts.
4. Normalizing input (like currency codes) at the entry point prevents cache fragmentation and redundant database checks.

**Action:**
- Always prefer string concatenation over `fmt.Sprintf` for simple templates.
- Use `strconv.Quote` when building JSON manually.
- Use atomic SQL (ON CONFLICT) for idempotency checks in high-concurrency paths.
- Ensure input normalization before cache/DB lookups.
