# 💳 Paycif (formerly ZapPay)

### World-Class Fintech Solution for QR Payments & Transfers

Paycif is a high-performance, security-first fintech application built with a hybrid architecture
combining **Flutter**, **Go**, and **Rust**. It focuses on speed, reliability, and cryptographic
security for modern digital payments.

---

## 🚀 Quick Start Guide

### 1. Prerequisites

- **Flutter SDK** (3.x+)
- **Go** (1.24+)
- **Rust/Cargo** (Latest stable)
- **Supabase Account** (For database and auth)

### 2. Backend Setup

The backend consists of a **Go API Gateway** and a **Rust FX Engine** communicating via Unix Domain
Sockets (UDS).

```bash
cd back-end
# Start all services (Redis, Rust FX Engine, and Go API)
./start-all.sh
```

_Backend runs on `http://localhost:8080`_

### 3. Frontend Setup

```bash
cd frontend
flutter pub get
flutter run
```

---

## 🏗️ System Architecture

### **The Hybrid Engine Strategy**

- **Frontend (Flutter):** High-fidelity UI with smooth animations and biometric security.
- **API Gateway (Go):** Handles authentication (Supabase), routing, and orchestration.
- **Core Engine (Rust):** High-performance cryptographic operations (Signature verification) and FX
  Rate calculations.

### **Security Model**

- **Dual-Layer Signatures:** Every transaction is signed on-device (Ed25519) and verified in the
  Rust sandbox.
- **Idempotency:** Strict enforcement to prevent double-spending.
- **Real-time Monitoring:** Granular notification system for wallet activity.

---

## 📂 Project Structure

```text
├── back-end/               # Go & Rust Backend
│   ├── cmd/api/            # Entry point for Go API
│   ├── internal/           # Business logic & services
│   ├── rust/fx-engine/     # Rust-performance critical engine
│   └── start-all.sh        # Orchestration script
├── frontend/               # Flutter Mobile App
│   ├── lib/features/       # Feature-driven architecture
│   └── lib/services/       # Global services (Auth, FCM, etc.)
└── docs/                   # Detailed documentation & reports
```

---

## 📖 Detailed Documentation

- [Backend Testing Guide](./docs/testing_guide.md)
- [FCM Notification Implementation](./docs/fcm_setup.md)
- [Security Audit & Reports](./docs/migration_history.md)

---

## 🛠️ Common Commands

| Target       | Command                | Description                   |
| :----------- | :--------------------- | :---------------------------- |
| **Backend**  | `./start-all.sh`       | Clean run of all services     |
| **Backend**  | `tail -f logs/api.log` | View real-time API logs       |
| **Frontend** | `flutter run`          | Start app in debug mode       |
| **Frontend** | `ls -d .*/`            | Check for hidden config files |

---

_Created with ❤️ by the Methas Pakpoompong Sut28 CPE 25_
