# Bolt's Performance Journal

## 2026-07-19 - WalletService Optimizations
**Learning:** Reverting to `fmt.Sprintf` and separate query-before-insert pattern `SELECT EXISTS` in high-concurrency wallet ledger pathways causes a ~2x latency increase and significantly higher serialization failure rate due to redundant database roundtrips. String formatting via `fmt.Sprintf` for key/payload construction in hot paths introduces multiple extra heap allocations.
**Action:** Replace `fmt.Sprintf` with manual string concatenation and `strconv.FormatFloat` to optimize hot-path CPU/memory usage. Utilize atomic `ON CONFLICT (reference_id) DO NOTHING` in SQL inserts to achieve single-roundtrip idempotency.
