# Tourist Wallet API Testing Guide

Use the following `curl` commands to test the API. Replace the placeholders with your actual values.

## Prerequisites
- **JWT Token**: Get a valid Supabase JWT for your user.
- **Wallet IDs**: You need UUIDs for sender and receiver wallets.
- **Idempotency Key**: Use a unique string (e.g., UUID) for each transfer attempt.

## 1. Check Balance
**GET** `/api/v1/balance`

```bash
curl -X GET "http://localhost:8080/api/v1/balance?currency=THB" \
  -H "Authorization: Bearer <YOUR_SUPABASE_JWT>" \
  -H "Content-Type: application/json"
```

## 2. Transfer Funds
**POST** `/api/v1/transfer`

```bash
curl -X POST "http://localhost:8080/api/v1/transfer" \
  -H "Authorization: Bearer <YOUR_SUPABASE_JWT>" \
  -H "Content-Type: application/json" \
  -d '{
    "from_wallet_id": "<SENDER_WALLET_UUID>",
    "to_wallet_id": "<RECEIVER_WALLET_UUID>",
    "amount": 10000, 
    "currency": "THB",
    "idempotency_key": "<UNIQUE_IDEMPOTENCY_KEY>",
    "description": "Dinner payment"
  }'
```
*Note: Amount is in minor units (e.g., Satang). 10000 = ฿100.00*

## Expected Errors
- **401 Unauthorized**: If Token is missing or invalid.
- **400 Bad Request**: If Validation fails or Limit exceeded (e.g. > ฿5,000).
- **409 Conflict**: If `idempotency_key` is reused for a different request (or sometimes same request if strictly configured).
