## 2026-08-23 - Redis Cache Key String Concatenation Optimization
**Learning:** Replacing `fmt.Sprintf` with direct string concatenation for Redis cache key construction (`"vpn_check:" + ip` and `"geo_country:" + ip`) achieves a ~4.6x speedup (from 113.5 ns/op down to 24.3 ns/op) and completely eliminates heap allocations (0 B/op vs 24 B/op).
**Action:** Always favor direct string concatenation over `fmt.Sprintf` for static prefix/suffix key generation on hot paths.
