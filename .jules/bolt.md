## 2026-08-26 - SQRIL Provider URL formatting optimization
**Learning:** In SQRIL provider transaction lookups (`GetTransaction`), using direct string concatenation (`s.BaseURL + "/getTransaction?transaction_id=" + transactionID`) instead of `fmt.Sprintf` reduces allocation overhead and execution time on API call paths.
**Action:** Prefer direct string concatenation for constructing API URLs and cache keys in Go usecase services.
