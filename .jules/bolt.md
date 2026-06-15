## 2026-06-12 - [Cache Fragmentation in WalletService]
**Learning:** Cache keys for currency pairs in `GetExchangeRate` were case-sensitive while DB queries were case-insensitive, leading to redundant DB lookups and cache entries for mixed-case inputs (e.g., 'usd' vs 'USD').
**Action:** Always normalize currency codes to uppercase at the entry point of service methods before cache key generation or database interaction.
