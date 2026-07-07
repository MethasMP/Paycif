## 2026-07-03 - [GetExchangeRate Cache Key Optimization]
**Learning:** In Go hot paths, `fmt.Sprintf` is significantly slower (~3.7x) than direct string concatenation because it parses the format string at runtime.
**Action:** Use direct string concatenation for cache keys and simple string patterns in performance-critical sections.
