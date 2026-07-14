## 2026-07-08 - [Atomic Idempotency & Manual JSON in WalletService]
**Learning:** Consolidating idempotency checks in PostgreSQL via `INSERT ... ON CONFLICT (reference_id) DO NOTHING` and checking `result.RowsAffected()` reduces database roundtrips and transaction duration. Additionally, manual JSON construction using `strconv.Quote` and string concatenation in Go hot paths is significantly faster than `json.Marshal` or `fmt.Sprintf` and avoids reflection overhead.
**Action:** Always favor atomic idempotency for high-concurrency transaction endpoints. Use `strconv.Quote` for safe manual JSON building in performance-critical paths.

## 2026-07-08 - [Standard Library Errors for PgError]
**Learning:** Avoid non-standard error handling helpers like `errors.AsType`. Use the standard `errors.As(err, &pgErr)` for robustness and compatibility with current Go versions and `pgx/v5`.
**Action:** Standardize on `errors.As` for all PostgreSQL error code checks.
