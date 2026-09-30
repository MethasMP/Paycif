## 2026-09-30 - Zero-Allocation IP & CIDR Matching with net/netip
**Learning:** `net.ParseIP` allocates a slice on the heap for every lookup. Standard library `net/netip` (`netip.ParseAddr` and `netip.Prefix`) provides stack-allocated value types that eliminate heap allocations (0 B/op, 0 allocs/op) on hot HTTP request routing paths like Cloudflare WAF bypass and geofence checks.
**Action:** Always prefer `net/netip` over `net.IP`/`net.IPNet` for high-throughput IP checking and CIDR range matching.
