
## 2026-07-05 - [Hot Path Optimization in WalletService]
**Learning:** Consolidating idempotency checks into a single `INSERT ... ON CONFLICT DO NOTHING` saves a DB roundtrip, which is more impactful than micro-optimizing string formatting. However, manual JSON construction with `strconv.Quote` provides both performance gains (~2x) and data safety compared to `fmt.Sprintf` with raw strings.
**Action:** Always prefer `ON CONFLICT` for idempotency in Postgres and use `strconv.Quote` when manually building JSON strings for hot paths to avoid malformed JSON bugs while maintaining speed.

## 2026-07-06 - [Performance vs Maintainability: Using Sonic]
**Learning:** While manual JSON construction is slightly faster, using `github.com/bytedance/sonic` (already a dependency) provides a better balance of performance (~3x faster than stdlib) and maintainability, avoiding error-prone string manipulation.
**Action:** Use `sonic.MarshalString` for high-performance paths when standard `json.Marshal` is a bottleneck, rather than manual string concatenation.
