## 2026-07-03 - [Hot-Path Optimization in WalletService]
**Learning:** In high-concurrency Go services using SERIALIZABLE isolation, combining idempotency checks with inserts using `ON CONFLICT DO NOTHING` significantly reduces transaction duration and serialization conflict probability. Additionally, `fmt.Sprintf` is ~3-5x slower than string concatenation and `strconv` for hot-path cache keys and manual JSON construction.
**Action:** Use atomic SQL operations and prefer string concatenation with `strconv.Quote` for performance-critical paths and safe JSON manual assembly.
