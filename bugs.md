# Bug Report — Paycif Whole Codebase — 2026-06-21

## Summary
- Critical: 0 open, 1 fixed
- Intermediate: 0 open, 1 fixed
- Normal: 0 open, 0 fixed

## 🔴 Critical

## 🟡 Intermediate

## 🟢 Normal

## ✅ Resolved

### BUG-001: Bypassable Local PIN Verification on Out of Sync credentials — Fixed 2026-06-21
- **File:** [security_repository_impl.dart](file:///Users/methas/Desktop/Paycif/frontend/lib/features/security/data/repositories/security_repository_impl.dart#L285-L289)
- **Issue:** The local optimistic PIN verification resolves successfully to the caller as soon as the local hash matches, but the server-side validation runs asynchronously in the background. If the background verification fails (e.g. because the PIN was changed/rotated on another device and the local hash is out of sync), the application has already granted access or let the user proceed.
- **Trigger:** 
  1. A user updates their PIN on Device A.
  2. On Device B, the user enters the old PIN.
  3. The local hash check passes (since it is cached on Device B's disk/memory).
  4. `verifyPin` returns successfully. The user gains access to the app interface.
  5. The background server verification fails silently in the background, only printing a debug log.
- **Impact:** Unauthorized access to user settings or cached credentials when PIN states are out of sync across devices.
- **Fix:** Added `await clearAllPinData()` inside the catch block of background server verification. If the server rejects the PIN, the local cache is immediately cleared, preventing subsequent optimistic bypasses.

### BUG-002: Ignored DB Execution Errors in Worker Refund Flow — Fixed 2026-06-21
- **File:** [outbox_worker.go](file:///Users/methas/Desktop/Paycif/back-end/internal/adapter/queue/outbox_worker.go#L252-L263)
- **Issue:** In the payout failure rollback handler, database statement execution errors for inserting the credit refund ledger entry and updating the transaction status to `FAILED` are discarded using `_, _ = refundTx.ExecContext(...)`.
- **Trigger:** A database constraint violation or connection glitch occurs during the refund insertion query execution.
- **Impact:** The database execution fails, but the transaction still attempts to commit. If the query failed due to a constraint, the commit fails, but if the execution fails without failing the transaction commit, the ledger is left unbalanced (funds debited but never refunded).
- **Fix:** Properly capture and check errors for all SQL execution statements, failing/rolling back the transaction cleanly if errors are found.
