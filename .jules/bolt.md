# Bolt's Performance Journal

This journal documents critical performance learnings, bottlenecks, and optimizations identified in the Paycif codebase.

## 2026-07-18 - Go Verify Service UDS Latency vs. Memory Allocation
**Learning:** In the performance-sensitive Go `verify-service`, base64 decoding was allocating slices and performing redundant validation checks, while the API server is extremely hot. While using `unsafe` is highly performant, standard Go slice operations are robust and safe.
**Action:** Always measure UDS socket request latency and optimize memory allocations and path formatting.
