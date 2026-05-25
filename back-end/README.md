# 🛠️ Paycif Backend (Go + Rust)

This is the core engine of Paycif, designed for extreme throughput and high security.

---

## 🏗️ Architecture

### **1. API Gateway (Go)**

- Located in: `back-end/`
- **Role**: Authentication (via Supabase), Route Management, Rate Limiting, and Orchestration.
- **Framework**: [Gin Gonic](https://github.com/gin-gonic/gin)

### **2. FX & Security Engine (Rust)**

- Located in: `back-end/rust/fx-engine`
- **Role**: CPU-intensive tasks.
  - Ed25519 Signature Verification
  - Complex FX Calculations (Floating point precision management)
- **Communication**: Via Unix Domain Socket (UDS) using Protobuf.

---

## 🚀 How to Run

### **Option A: The Orchestrator (Recommended)**

```bash
./start-all.sh
```

This script cleans up old processes, builds the Rust engine, and starts the Go server.

### **Option B: Manual Execution**

1. **Start Rust Engine**:
   ```bash
   cd rust/fx-engine
   cargo run --release
   ```
2. **Start Go API**:
   ```bash
   go run cmd/api/main.go
   ```

---

## 🛠️ Development & Debugging

- **Logs**: All logs are directed to the `logs/` directory.
- **Testing**: Run `./docs/testing_guide.md` curl commands to verify endpoints.
- **Environment**: Ensure `.env` is correctly configured with `SUPABASE_URL` and `DATABASE_URL`.

---

_Fintech excellence through memory safety (Rust) and concurrency (Go)._
