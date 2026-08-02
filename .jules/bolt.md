# Bolt's Performance Journal

## 2026-08-02 - [Exchange Rate Cache Key Generation Optimization]
**Learning:** Cache key generation via `fmt.Sprintf` is highly inefficient as it utilizes reflection and format string parsing, leading to heap allocations and reduced throughput. Switching to manual string concatenation achieves a ~3.84x speedup (138.7 ns/op to 36.11 ns/op) and entirely eliminates heap allocations (from 1 alloc/op to 0 allocs/op).
**Action:** Always favor simple string concatenation (`+`) instead of `fmt.Sprintf` when constructing hot-path keys, labels, or simple identifiers, as it compiles to highly optimized compiler operations.
