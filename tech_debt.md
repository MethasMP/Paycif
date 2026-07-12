# Technical Debt / Workarounds

## Mocks
- **Payment API (`/payout/promptpay`)**: [RESOLVED] Bypassed and mock code has been removed. The real API call has been fully integrated in `PaymentRepositoryImpl` and `ApiService`.
