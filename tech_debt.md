# Technical Debt / Workarounds

## Mocks
- **Payment API (`/payout/promptpay`)**: The actual API call in `lib/cubit/payment_cubit.dart` (`pay` method) is currently bypassed and mocked to always succeed after a 1-second delay. This allows testing the UI flow to the receipt page without a backend. Needs to be reverted once the API is ready.
