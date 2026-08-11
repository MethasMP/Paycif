## 2026-08-11 - [IP Geofence & Bypass Detection Modernization via net/netip]
**Learning:** Migrated legacy `"net"` package usages to `"net/netip"` inside `geo_block_service.go` and `cloudflare_ip_service.go`. The modern `net/netip` standard library operates on flat, pointer-free, contiguous value structures (`netip.Addr` and `netip.Prefix`) that are significantly more friendly to the CPU cache and heap.
- Side-by-side Go benchmarks verified that IPv6 address truncation is ~1.46x faster with half the memory footprint (exactly 1 heap allocation vs 2) and CIDR/subnet checks are ~1.74x faster with zero heap allocations on hot paths.
**Action:** Always favor `net/netip` over `net` for performance-critical IP handling, address parsing, and geofence/CIDR lookup operations.
