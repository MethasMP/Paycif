# Bolt's Performance Journal ⚡

## 2026-08-07 - UDS HTTP Connection Pooling & Client Reuse
**Learning:** Unix Domain Sockets (UDS) are highly efficient for local IPC, but instantiating a new Go `http.Client` and `http.Transport` on every request destroys performance. It causes constant socket dials, disables connection keep-alives/pooling, and drastically increases heap allocations (~34 KB per operation down to ~9.3 KB per operation, and 173 down to 103 allocations).
**Action:** Always maintain a single, cached thread-safe `*http.Client` with a shared transport inside usecase services that interact with background processes via UDS. Protect instantiation paths with a fallback check (`if client == nil`) to preserve test compatibility and prevent nil pointer dereferences.
