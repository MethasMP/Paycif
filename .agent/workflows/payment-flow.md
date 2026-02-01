---
description: Standard Payment Flow following Thai Banking Standards
---

# 🏦 Paysif Payment Flow (Thai Banking Standard)

## Overview

This document describes the complete payment flow for Paysif, following Thai banking standards
similar to K PLUS, SCB EASY, and PromptPay.

---

## 📱 User Journey (Step-by-Step)

### Step 1: Scan QR Code

- User opens app and scans PromptPay QR
- App decodes: `promptPayId`, `merchantName`, `amount` (if present)
- Navigate to **Amount Entry Screen**

### Step 2: Enter Amount

- User enters amount using virtual keypad
- Display recipient info (name, PromptPay ID)
- Tap "Review Payment" → Navigate to **Confirmation Screen**

### Step 3: Confirmation Screen (NEW - Thai Standard)

- Display: Amount, Recipient Name, PromptPay ID
- Display: **Wallet Balance** (MUST show correct balance)
- Display: Fee breakdown (if any)
- Button: "Confirm Payment" (with amount)
- **Security**: May require PIN/Biometric before proceeding

### Step 4: Processing

- Show loading spinner with "Processing..."
- Backend: Deduct from wallet, create ledger entry, queue payout
- Timeout: Max 30 seconds

### Step 5: Success Receipt Screen (NEW - Thai Standard)

**MUST Include:**

- ✅ Success checkmark animation
- 📋 Transaction Reference Number
- 💰 Amount Paid
- 👤 Recipient Name & PromptPay ID
- 📅 Date & Time
- 💳 Payment Method (Paysif Wallet)
- 💰 Remaining Balance
- 📥 "Save Receipt" button (optional)
- ✅ "Done" button → Return to Home

### Step 6: (Background) Actual PromptPay Transfer

- Worker reads from `transaction_outbox`
- Calls Bank API (SCB/KBANK) to execute real transfer
- Updates transaction status: PENDING → COMPLETED

---

## 🔧 Technical Implementation

### Frontend Files to Update:

1. `pay_screen.dart` - Show correct balance
2. `payment_success_screen.dart` - NEW: Receipt screen
3. `payment_cubit.dart` - Navigate to success screen

### Backend Endpoints:

| Endpoint                   | Method | Description             |
| -------------------------- | ------ | ----------------------- |
| `/api/v1/balance`          | GET    | Get wallet balance      |
| `/api/v1/payout/promptpay` | POST   | Execute payout          |
| `/api/v1/transactions`     | GET    | Get transaction history |

### Database Tables:

- `wallets` - User balance
- `transactions` - Transaction records
- `ledger_entries` - Double-entry bookkeeping
- `transaction_outbox` - Queue for async processing

---

## 🐛 Known Issues (Current)

1. **Balance shows ฿0.00** - Frontend may not be parsing response correctly
2. **No Receipt Screen** - Need to create new screen
3. **No transaction history update** - Need to refresh after payment

---

## 📋 Checklist for Implementation

- [ ] Fix balance display issue
- [ ] Create PaymentSuccessScreen with receipt
- [ ] Add transaction reference to success response
- [ ] Navigate to success screen after payment
- [ ] Show remaining balance on success screen
