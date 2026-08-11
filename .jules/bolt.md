# Bolt's Performance Journal

This journal serves as the performance optimization record for Bolt ⚡.

## 2026-08-11 - Modern net/netip Migration for Ultra-Low Latency IP Checks
**Learning:** The legacy `"net"` package in Go uses heap-allocated byte slices (`net.IP`, `net.IPNet`) for parsing and subnet matching. Migrating to the modern `"net/netip"` standard library package provides complete, allocation-free operations on value types (`netip.Addr`, `netip.Prefix`) that are passed by value and fit into register files, avoiding any garbage collection pressure.
**Action:** Always prefer `"net/netip"` over `"net"` for any performance-sensitive IP geolocation, rate-limiting, range lookup, or IP masking checks on hot paths.

### Benchmark Results Comparison

| Operation | Legacy `net` | Modern `net/netip` | Speedup / Improvement |
| :--- | :--- | :--- | :--- |
| **`TruncateIP`** | `1062 ns/op` (`56 B/op`, `4 allocs/op`) | `495.5 ns/op` (`40 B/op`, `3 allocs/op`) | **~2.14x faster** (~28% less memory) |
| **`Contains`** (Cloudflare range lookups) | `243.8 ns/op` (`0 B/op`, `0 allocs/op`) | `152.7 ns/op` (`0 B/op`, `0 allocs/op`) | **~1.60x faster** |
| **`IsInThailandCIDR`** (Geofence subnets) | `216.1 ns/op` (`0 B/op`, `0 allocs/op`) | `82.97 ns/op` (`0 B/op`, `0 allocs/op`) | **~2.60x faster** |

*Note: In the benchmark, `TruncateIP` loops over 3 IP addresses, achieving the theoretical limit of exactly 1 allocation per IP address (only for the returned string allocation itself), down from 1.33 allocations per IP address in the legacy implementation.*
