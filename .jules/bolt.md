# Bolt Performance Journal

## 2026-07-30 - Reuse UDS http.Client in SignatureService
**Learning:** Creating a new `http.Client` and `http.Transport` dynamically inside a request-handling function is a severe Go anti-pattern. It disables TCP/UDS connection keep-alives, forces connection setup and teardown overhead on every call, increases memory allocation and GC pressure, and risks socket/file descriptor exhaustion under load.
**Action:** Always instantiate and reuse a single, thread-safe `http.Client` and `http.Transport` at the service-struct level (or package level) during initialization.
