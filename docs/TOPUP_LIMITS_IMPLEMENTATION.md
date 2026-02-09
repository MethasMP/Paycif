# Daily Top-up Limits Implementation Summary

## Overview
Implemented daily top-up limits system:
- **Minimum**: 500 THB per transaction
- **Maximum**: 3,000 THB per day

## Changes Made

### 1. Database Schema (`supabase/migrations/20240202_add_daily_topup_limits.sql`)
- Created `private.daily_topup_tracking` table to track daily totals per user
- Added `check_and_update_daily_topup()` function - atomically checks limits and updates totals
- Added `get_daily_topup_status()` function - returns current usage without modifying
- Enforced constraints:
  - Min per transaction: 50,000 satang (500 THB)
  - Max per day: 300,000 satang (3,000 THB)

### 2. Backend - Edge Functions

#### `get-topup-status` (NEW)
- Returns user's current daily top-up status
- Converts satang to baht for frontend consumption
- Shows: current_total, max_daily, remaining_limit, min_per_transaction

#### `inbound-handler` (MODIFIED)
- Added limit validation BEFORE processing payment
- Checks minimum amount (500 THB)
- Checks daily limit via database function
- Returns clear error messages when limits exceeded
- Logs limit check results for audit trail

### 3. Frontend - TopUp Screen (`frontend/lib/screens/top_up_view.dart`)

#### State Management
- Added `_dailyLimit`, `_dailyUsed`, `_dailyRemaining`, `_minPerTransaction` tracking
- Added `_isLimitLoading` and `_limitError` for UI states
- Updated `_smartAmounts` to [500, 1000, 2000, 3000] (max 3000)

#### API Service (`frontend/lib/services/api_service.dart`)
- Added `getDailyTopUpStatus()` method to fetch limits from backend

#### UI Components
1. **Limit Indicator** (`_buildLimitIndicator`)
   - Shows loading state while fetching limits
   - Shows error state if fetch fails
   - Displays: "Limit: ฿X/฿3,000"
   - Warning state (orange) when < 1,000 remaining
   - Error state (red) when limit reached

2. **Smart Suggestions** (`_buildSmartSuggestions`)
   - Disables chip buttons that exceed remaining daily limit
   - Visual feedback: greyed out, reduced opacity
   - Prevents selecting amounts that would exceed limit

3. **Pay Button** (`_buildPayButton`)
   - Validates minimum amount (>= 500 THB)
   - Validates against daily remaining limit
   - Button disabled if validations fail
   - Prevents proceeding to review if limits exceeded

#### Lifecycle
- Fetches daily limits on `initState`
- Real-time validation as user enters amounts

## How It Works

### User Flow
1. User opens Top-up screen
2. System fetches daily limits from backend
3. UI displays current usage (e.g., "Limit: ฿0/฿3,000")
4. User enters amount:
   - If < 500 THB: Cannot proceed (button disabled)
   - If > remaining limit: Cannot proceed
   - Preset buttons disabled if they exceed limit
5. User proceeds to review → payment
6. Backend validates limits AGAIN before charging
7. If successful, daily total updated atomically

### Security
- Double validation: Frontend (UX) + Backend (security)
- Atomic database operations prevent race conditions
- Idempotency keys prevent double-counting
- Clear audit trail in logs

### Edge Cases Handled
- **New user**: Shows 0/3,000, all options available
- **Partial usage**: Disables only buttons exceeding remaining limit
- **Limit reached**: Shows red warning, all preset buttons disabled
- **Custom amount**: Validates in real-time against remaining limit
- **Race condition**: Database atomic check prevents over-limit even with concurrent requests

## Testing Checklist
- [ ] Top-up 500 THB (minimum) - should work
- [ ] Top-up 499 THB - should show error
- [ ] Top-up 3,000 THB - should work (if under limit)
- [ ] Top-up 3,001 THB - should fail
- [ ] Multiple top-ups: 1,000 + 1,000 + 1,000 = limit reached
- [ ] 4th top-up attempt should fail with "daily limit reached"
- [ ] UI updates correctly after each top-up
- [ ] Preset buttons disable when approaching limit
- [ ] Backend enforces limits even if frontend bypassed

## Next Steps (Optional Enhancements)
1. Add remaining limit indicator next to amount input
2. Show "Available today: ฿X" in review sheet
3. Add retry mechanism if limit check fails
4. Add analytics tracking for limit-related errors
5. Consider tiered limits (KYC Bronze/Silver/Gold)

## Files Modified
1. `supabase/migrations/20240202_add_daily_topup_limits.sql` (NEW)
2. `supabase/functions/get-topup-status/index.ts` (NEW)
3. `supabase/functions/inbound-handler/index.ts` (MODIFIED)
4. `frontend/lib/services/api_service.dart` (MODIFIED)
5. `frontend/lib/screens/top_up_view.dart` (MODIFIED)
