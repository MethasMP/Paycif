# Bolt Journal ⚡

## 2026-06-24 - [WalletService] GetExchangeRate Cache Key Optimization
**Learning:** `fmt.Sprintf` is significantly slower than string concatenation in Go due to reflection and allocation overhead. In this codebase, string concatenation (~37ns/op) proved to be ~3.5x faster than `fmt.Sprintf` (~130ns/op). Additionally, normalizing input strings (e.g., currency codes to uppercase) before cache lookup prevents cache fragmentation, ensuring that 'usd' and 'USD' map to the same entry.
**Action:** Prefer string concatenation for simple string building in hot paths. Always normalize inputs that form part of a cache key.

### Benchmarks (Intel(R) Xeon(R) Processor @ 2.30GHz)
- `fmt.Sprintf("rate:%s:%s", from, to)`: 129.9 ns/op
- `"rate:" + from + ":" + to`: 36.76 ns/op
- `"rate:" + strings.ToUpper(from) + ":" + strings.ToUpper(to)`: 129.4 ns/op (Used to ensure cache hit consistency)
