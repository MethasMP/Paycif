# 📱 Paycif Mobile (Flutter)

Premium mobile application for the Paycif fintech ecosystem.

---

## 🎨 Design Philosophy

- **Aesthetics**: Modern, dark-mode focused, glassmorphism UI elements.
- **UX**: High-performance lists, skeleton loading, and optimistic UI updates.

---

## 🛠️ Tech Stack

- **Framework**: Flutter 3.x (Dart)
- **State Management**: BLoC / Provider
- **Networking**: Dio (with centralized interceptors for security)
- **Security**:
  - Biometric Auth (Local Auth)
  - Secure Storage (Encrypted Keyring)
  - On-device Transaction Signing (Ed25519)

---

## 🚀 Getting Started

### 1. Installation

```bash
flutter pub get
```

### 2. Configuration

Ensure `.env` exists in the root of the `frontend/` directory with:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `BACKEND_URL` (Pointing to your Go API)

### 3. Running

```bash
flutter run
```

---

## 📁 Key Directories

- `lib/features/`: Feature-sliced components (Security, Notification, Wallet).
- `lib/services/`: Core infrastructure (API, Auth, Push).
- `lib/widgets/`: Reusable UI components.

---

_Building the future of digital payments._
