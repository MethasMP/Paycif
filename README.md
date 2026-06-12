# 💳 Paycif

**Instant, Secure QR Payments Built for Institutional Trust.**

Paycif is a high-performance fintech application designed to process QR payments and transfers with zero friction and absolute cryptographic security. Built for scale, it guarantees idempotency and real-time synchronization, ensuring that consumers experience velocity and stability in every transaction.

## Key Features

- **Instant QR Transactions:** Ultra-low latency payment routing and processing.
- **Cryptographic Security:** Dual-layer Ed25519 signatures verified on-device and in the backend.
- **Zero Double-Spending:** Strict idempotency checks backed by PostgreSQL distributed locking.
- **Real-time Synchronization:** Instantaneous wallet updates via WebSockets and Supabase real-time.

---

## 🛠 Tech Stack

- **Frontend:** Flutter (Mobile App)
- **Backend:** Go 1.24+ (API Gateway & Microservices)
- **Database:** PostgreSQL 16+ via Supabase
- **Real-time/Auth:** Supabase Auth & Realtime
- **Queueing:** PostgreSQL `SKIP LOCKED` / `LISTEN/NOTIFY`

---

## 🚦 Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (3.x+)
- **Go** (1.24+)
- **Supabase CLI** (For local database development)
- **Git**

---

## 🚀 Getting Started

Follow these steps to get the complete Paycif stack running on your local machine.

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/paycif.git
cd paycif
```

### 2. Database & Infrastructure Setup (Supabase)

We use the Supabase CLI to manage our local database environment and migrations.

```bash
# Start local Supabase instance
supabase start

# Apply all migrations and seed data
supabase db push
```

### 3. Backend Setup (Go)

The backend consists of an API Gateway and background microservices.

```bash
cd back-end

# Download Go modules
go mod download

# Start all Go services
./start-all.sh
```
*The API Gateway will be available at `http://localhost:8080`*

### 4. Frontend Setup (Flutter)

```bash
cd frontend

# Get Flutter packages
flutter pub get

# Run the app on your connected device or emulator
flutter run
```

---

## 📐 Architecture

### Directory Structure

```text
paycif/
├── back-end/               # Go Backend Services
│   ├── cmd/api/            # Entry point for the Go API Server
│   ├── internal/           # Core business logic
│   │   ├── queue/          # Job queue workers and enqueuers
│   │   └── services/       # Domain-specific services (Payments, FX)
│   ├── database/           # DB connection pools and schema definitions
│   └── start-all.sh        # Local environment orchestration script
│
├── frontend/               # Flutter Mobile App
│   ├── lib/features/       # Feature-driven UI components
│   ├── lib/services/       # Global services (Auth, FCM, API clients)
│   └── pubspec.yaml        # Flutter dependencies
│
├── supabase/               # Infrastructure as Code
│   ├── migrations/         # SQL schema definitions and RLS policies
│   └── config.toml         # Supabase local environment config
│
├── AGENT.md                # AI Harness rules
└── PRODUCT.md              # Strategic product context
```

### Request Lifecycle

1. **User Action:** User scans a QR code in the Flutter app.
2. **Device Signature:** The app signs the transaction payload using the device's private key (Ed25519).
3. **API Gateway:** The request hits the Go API Gateway.
4. **Authentication & Validation:** Go validates the JWT via Supabase Auth and cryptographically verifies the Ed25519 signature.
5. **Idempotency Check:** Go checks the database to ensure the transaction hasn't been processed.
6. **Execution:** The transaction is written to PostgreSQL within a strict ACID transaction.
7. **Async Tasks:** A job is enqueued for push notifications. The `internal/queue` worker picks it up instantly via `LISTEN/NOTIFY`.
8. **Real-time Update:** The Flutter app receives a WebSocket update reflecting the new balance.

### Database Schema (Core)

```text
jobs (Queue System)
├── id (uuid, PK)
├── type (varchar)
├── payload (jsonb)
├── status (varchar: pending/processing/completed/failed)
├── created_at (timestamptz)
└── locked_at (timestamptz)
```

---

## ⚙️ Environment Variables

### Backend (`back-end/.env`)

| Variable | Description | Example |
|---|---|---|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://postgres:postgres@localhost:54322/postgres` |
| `SUPABASE_URL` | API URL for Supabase | `http://127.0.0.1:54321` |
| `GIN_MODE` | Framework mode | `debug` or `release` |

---

## 🧪 Testing

All services are heavily tested to ensure financial integrity.

### Backend (Go)

```bash
cd back-end

# Run all unit and integration tests
go test ./...

# Run with race detector
go test -race ./...
```

### Frontend (Flutter)

```bash
cd frontend

# Run widget and unit tests
flutter test
```

---

## 🚨 Troubleshooting

### Database Connection Refused
**Error:** `failed to connect to host=localhost user=postgres database=postgres`
**Solution:** Ensure Supabase is running locally. Run `supabase status` to check if the database container is healthy. If not, run `supabase start`.

### Stuck Queue Jobs
**Error:** Background tasks like emails aren't sending.
**Solution:** Check the Go worker logs. If a worker crashed mid-job, the Reclaimer routine will automatically unlock and retry the job after 5 minutes.

---

## 📜 Development Guidelines

We adhere strictly to the rules defined in `AGENT.md` and the design principles in `PRODUCT.md`.
- **Clean Code:** SOLID principles and separation of concerns are mandatory.
- **Micro vs Macro Tasks:** Significant architectural changes require an `implementation_plan.md` and explicit approval.
- **Closed-Loop Delivery:** Verify your own work before considering it complete.

*Engineered with precision. Built for trust.*
