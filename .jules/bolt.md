## 2026-10-29 - Zero-Allocation Hash Computation with `hash.Hash.Sum(buf[:0])`
**Learning:** In Go, calling `h.Sum(nil)` allocates a byte slice on the heap. Passing `res[:0]` backed by a stack-allocated array `var res [32]byte` to `h.Sum(res[:0])` allows `hash.Hash` to append the digest directly into the stack array, completely avoiding heap allocations (0 B/op, 0 allocs/op).
**Action:** Always use `h.Sum(buf[:0])` with a fixed stack array `var buf [32]byte` when computing SHA-256 digests in hot crypto/hash paths.
