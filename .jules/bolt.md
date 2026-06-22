
## 2026-06-21 - GetExchangeRate Cache Key Optimization
**Learning:** Using `fmt.Sprintf` for simple cache key generation in Go is ~3.5x slower than string concatenation (110ns vs 32ns). Furthermore, cache fragmentation was occurring because currency inputs were not normalized before cache lookup, leading to redundant DB queries for 'usd' vs 'USD'.
**Action:** Always normalize string keys at the entry point of a service and prefer string concatenation for simple key formatting to maximize cache hit rates and minimize overhead.
