## 2026-07-11 - WalletService Performance Baseline
**Learning:** Manual string concatenation and JSON construction in Go hot paths significantly outperform fmt.Sprintf and json.Marshal.
- Cache Key: ~3.6x speedup (131ns -> 36ns)
- Description: ~2.1x speedup (171ns -> 78ns)
- Metadata: ~3.3x speedup (1079ns -> 319ns)
- Outbox Payload: ~1.5x speedup (915ns -> 604ns)
**Action:** Apply these patterns to WalletService hot paths and replace redundant DB checks with atomic SQL where possible.
