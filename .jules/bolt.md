
## 2026-06-12 - [Currency Normalization in Cache Keys]
**Learning:** Inconsistent casing in currency codes (e.g., "usd" vs "USD") was causing cache fragmentation in `WalletService.GetExchangeRate`. The database query already used `strings.ToUpper`, but the cache key was generated from the raw input, leading to redundant database calls and wasted memory.
**Action:** Always normalize currency codes and other categorical keys to a standard case (usually uppercase) BEFORE generating cache keys or performing lookups.
