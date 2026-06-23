# 🛠️ Paycif Backend (Pure Go)

This is the core engine of Paycif, designed for extreme throughput and high security.

---

## 🏗️ Architecture

### **1. API Gateway (Go)**

- Located in: `cmd/api/`
- **Role**: Authentication (via Supabase), Route Management, Rate Limiting, and Orchestration.
- **Framework**: [Gin Gonic](https://github.com/gin-gonic/gin)

### **2. FX & Security Engine (Go)**

- Located in: `cmd/fx-engine/`
- **Role**: High-performance background services.
  - Ed25519 Signature Verification
  - Complex FX Calculations (Floating point precision management)
- **Communication**: Via Unix Domain Socket (UDS) using Protobuf.

---

## 🚀 How to Run

### **Option A: The Orchestrator (Recommended)**

```bash
./start-all.sh
```

This script cleans up old processes, builds all Go microservices, and starts the API Gateway.

### **Option B: Manual Execution**

1. **Start FX Engine**:
   ```bash
   go run cmd/fx-engine/main.go
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

_Fintech excellence through optimized Go runtime concurrency and lockless event-driven design._
