# Bolt Performance Journal

## 2026-08-04 - [Cloudflare and Geofence Allocations Optimization]
**Learning:** Netip is much more performant than legacy standard net.IP. Replaced net.IP and net.IPNet with netip.Prefix and netip.Addr, achieving ~1.6x speedup for Cloudflare Contains checks and ~1.87x speedup for geofence matching.
**Action:** Always prefer net/netip library over net.IP/net.IPNet for IP checks.

## 2026-08-04 - [Geo Block Fallback Load Flag Latency Fix]
**Learning:** A failed load or download of th_cidrs.txt left the load atomic flag at 0, triggering expensive synchronous disk reads and external network requests on every single client request in the fallback path. Setting the flag to 1 on failure reduced fallback check latency from ~11.4 ms to ~35.2 ns (a ~325,000x speedup) while completely eliminating console log flooding.
**Action:** Ensure fallback error states set initialised/loaded flags correctly to avoid retrying slow IO paths synchronously.

## 2026-08-05 - [Signature Service HTTP/UDS Client Reuse]
**Learning:** Creating http.Client on every signature verification request was extremely expensive, especially over UDS. Reusing a thread-safe http.Client and http.Transport dialed via UDS reduced latency by ~6.49x (from ~178.9 µs to ~27.5 µs) and memory footprint by ~3.54x (from ~32.9 KB to ~9.3 KB) while reducing heap allocations by ~41%.
**Action:** Reuse HTTP clients and transports configured with custom dialers instead of instantiating them per request.
