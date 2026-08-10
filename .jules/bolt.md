# Bolt Performance Journal

This file contains Bolt's performance journal documenting critical learnings.

## 2026-08-09 - Modern `net/netip` Conversion & Load Fail Safeguard
**Learning:** Legacy Go `"net"` types like `net.IPNet` and `net.IP` allocate on the heap and are slower than modern Go `"net/netip"` (`netip.Prefix` and `netip.Addr`) structures, which are allocation-free and highly optimized. In addition, leaving the initialization atomic flag at `0` upon any fallback file-load or download failure triggers a catastrophic bug where subsequent client requests synchronously attempt to read from disk and hit the external network on every check, causing severe latency spikes (~66ms vs ~35ns).
**Action:** Always utilize `"net/netip"` on high-throughput IP paths (e.g. geofencing, CDN bypass, VPN detection) and apply a defer-recovery pattern (`defer atomic.StoreInt32(&loadedFlag, 1)`) inside the loader's mutex block to ensure that load failures are marked as completed, preventing expensive repeated file-system/network retries.
