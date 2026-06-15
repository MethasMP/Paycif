# Bolt's Journal - Critical Learnings Only

## 2026-06-12 - Optimization of ProcessPayment Idempotency
**Learning:** Collapsing a check-then-insert pattern into an atomic `INSERT ... ON CONFLICT DO NOTHING` reduces database round-trips and minimizes serialization conflicts in `SERIALIZABLE` isolation.
**Action:** Always look for ways to make operations atomic in high-concurrency environments.

## 2026-06-12 - Currency Normalization in GetExchangeRate
**Learning:** Cache fragmentation can occur if input keys (like currency codes) are not normalized (e.g., 'usd' vs 'USD'). Normalizing keys before cache lookups improves hit rates.
**Action:** Normalize all input data used as cache keys at the entry point of the function.

## 2026-06-12 - Adhering to PR Scope
**Learning:** Performance-focused agents should avoid making architectural or cosmetic changes (like package renaming) that are out of scope. These changes increase risk and can distract from the performance wins during code review.
**Action:** Keep performance PRs focused strictly on measurable efficiency gains. Correct existing bugs found during exploration only if they block the performance fix, and do so minimally.
