# Paycif Agent Guide

## Commit Messages
Every commit MUST include a "How to test" section in the body:
- **Live URL/Environment:** Where to verify the change.
- **Step-by-step instructions:** What to click or check.
- **Test Credentials:** If login is required.
- **Expected Result:** What success looks like.

### Example:
  feat: Add Coinflow integration schema
  
  How to test:
  1. Open Supabase Dashboard -> Table Editor.
  2. Check `profiles` table for `coinflow_customer_id` column.
  3. Verify that `transactions` table has a check constraint for `TOPUP` type.
