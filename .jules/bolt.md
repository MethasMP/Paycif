# Bolt's Performance Journal ⚡

Welcome to Bolt's Performance Journal. This log details critical performance learnings, high-impact optimizations, and architectural insights discovered during the course of engineering Paycif.

## 2026-08-04 - Linear Fallback Failure Loops & net/netip Performance Gains

**Learning:**
1. **Fallback I/O Latency Trap:** When loading local data file dependencies (such as CIDR geofence lists) dynamically in hot request paths, failure to update the loaded status flag on failure (or missing a cooldown/retry limit) causes the system to persistently initiate synchronous disk reads and external network requests on *every subsequent call*. In sandbox/production systems with blocked outbound internet or missing files, this causes severe latency degradation (surging from ~35ns to 11.4ms per request—a 325,000x penalty) and floods console logs with blockages.
2. **Standard net vs net/netip:** Standard Go `net.IP` and `net.IPNet` utilize slice-header comparison and linear matching which results in higher CPU overhead. Migrating CIDR matching and address resolution to the modern, value-type, allocation-free `net/netip` library provides a ~1.6x speedup for Cloudflare's published range containing-checks (~275ns down to ~168ns) and a ~2.0x speedup for Thailand CIDR list geofence checks (~1319ns down to ~704ns).

**Action:**
1. Always mark resources as loaded (even if failed) or implement an atomic cooldown limit when handling lazy-loaded configurations/databases inside request-serving hot paths to avoid synchronous retry/failure loops.
2. Prefer using the allocation-free, pointerless `net/netip` package for parsing IP addresses and matching network ranges (CIDRs) in high-frequency middleware and routing layers.
