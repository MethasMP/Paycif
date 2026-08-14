# Bolt's Performance Journal

This journal documents critical performance learnings, bottlenecks, and optimizations within the Paycif monorepo.

## 2026-08-13 - NFC Passport Passive Authentication Re-Optimization
**Learning:** Redundant parsing of incoming byte arrays on cryptographic validation paths introduces major allocation overhead and duplicate scan loops. In `sod_verifier.go`, DG1 was parsed once during the document signer certificate nationality lookup, and then parsed *again* as the final identity extraction step. Furthermore, scanning byte slices inside a loop by converting sliced segments (`string(data[i:])`) to intermediate strings creates a massive heap footprint. Moving the parsing of `DG1` upfront and scanning byte indexes directly to slice exactly the needed MRZ window (88-90 bytes) drastically reduces latency and memory overhead.
**Action:** Unify multiple parsing/validation phases into a single upfront parse step. When scanning raw byte buffers for markers, locate the boundary indexes directly within the `[]byte` slice first, then slice and convert exactly the required sub-segment rather than converting large remainder slices inside loops.
