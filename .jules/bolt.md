## 2026-06-11 - Database and Cache Optimization in WalletService

**Learning:** Redundant JOINs to the `transactions` table during limit checks can be avoided by filtering directly on `ledger_entries` if the necessary columns (like `created_at`) are present and indexed. Also, cache fragmentation occurs when input strings (like currency codes) are not normalized before being used as cache keys, leading to suboptimal hit rates.

**Action:** Always check if a JOIN can be eliminated by using indexed columns in the primary table. Normalize all lookup parameters (uppercase/lowercase/trim) before generating cache keys or performing database lookups.
