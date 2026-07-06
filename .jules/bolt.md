
## 2026-07-05 - [Hot Path Optimization in WalletService]
**Learning:** Consolidating idempotency checks into a single `INSERT ... ON CONFLICT DO NOTHING` saves a DB roundtrip, which is more impactful than micro-optimizing string formatting. However, manual JSON construction with `strconv.Quote` provides both performance gains (~2x) and data safety compared to `fmt.Sprintf` with raw strings.
**Action:** Always prefer `ON CONFLICT` for idempotency in Postgres and use `strconv.Quote` when manually building JSON strings for hot paths to avoid malformed JSON bugs while maintaining speed.
