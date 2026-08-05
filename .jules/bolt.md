## 2026-08-05 - Optimize Cache Key Generation in PaymentOrchestrationService
**Learning:** Replacing `fmt.Sprintf` with manual string concatenation in hot cache paths avoids reflection and format string parsing, reducing local cache-hit latency in `PaymentOrchestrationService.GetExchangeRate` from 369.6 ns/op to 163.3 ns/op (~2.26x speedup) and cutting heap allocations significantly.
**Action:** Always prefer manual string concatenation (e.g., `"prefix:" + arg1 + ":" + arg2`) over `fmt.Sprintf` for constructing cache keys or database lookup keys in performance-critical execution paths.
