## 2026-06-12 - [Cache Fragmentation & Key Generation]
**Learning:** In `WalletService.GetExchangeRate`, using raw input currency strings for cache keys led to fragmentation (e.g., 'usd' vs 'USD' being separate entries). Additionally, `fmt.Sprintf` for key generation in high-frequency paths adds significant overhead compared to simple string concatenation.
**Action:** Always normalize lookup keys (e.g., `strings.ToUpper`) before cache operations and prefer string concatenation over `fmt.Sprintf` for simple key building in performance-critical paths.
