# Bolt Performance Journal ⚡

## 2026-07-25 - [UDS HTTP Client Reuse in SignatureService]
**Learning:** Recreating a new `*http.Client` and `*http.Transport` on every request prevents HTTP connection pooling and keep-alives, resulting in significant socket Dial overhead and connection setup/teardown costs. This is particularly wasteful over Unix Domain Sockets (UDS) and under high concurrent load. Reusing a single pre-allocated `*http.Client` with appropriate pool parameters (`MaxIdleConns`, `IdleConnTimeout`, `MaxIdleConnsPerHost`) entirely solves this bottleneck. Additionally, setting up a local mock UDS server inside tests is highly effective for testing socket-based code cleanly and without external dependencies.
**Action:** Always verify if HTTP clients (especially those communicating with local sidecars or microservices over UDS/TCP) are instantiated as singletons or reused across requests.
