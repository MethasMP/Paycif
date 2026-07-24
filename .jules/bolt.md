# Bolt's Performance Journal

## 2026-07-24 - Sharing UDS HTTP Client
**Learning:** Re-instantiating `http.Client` and `http.Transport` on every request over Unix Domain Sockets (UDS) incurs a huge cost in socket allocation, file descriptor handshakes, and GC pressure because connection pooling is bypassed completely. Sharing a single configured `http.Client` and `http.Transport` instance yields a ~2.58x speedup and ~67.2% reduction in memory allocation.
**Action:** Always verify that HTTP and connection clients (especially over internal transports/UDS) are declared as long-lived structures and shared across concurrent workers.
