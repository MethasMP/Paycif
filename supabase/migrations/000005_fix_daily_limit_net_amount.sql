-- ============================================================================
-- FIX DAILY LIMIT TO USE NET AMOUNT (WALLET CREDIT) INSTEAD OF CHARGE AMOUNT
-- ============================================================================
-- Problem: Daily Limit was tracking CHARGE AMOUNT (520.33 THB) instead of 
--          WALLET CREDIT (500 THB). This caused users to hit limits faster
--          than expected and confused user expectations.
--
-- Solution: 
--   1. Update get_daily_topup_status to backfill from transactions.amount (NET)
--   2. Truncate daily_topup_tracking to force recalculation
--   3. Future top-ups will use NET amount via inbound-handler fix
-- ============================================================================

-- Step 1: Clear incorrect tracking data to force recalculation
TRUNCATE TABLE private.daily_topup_tracking;

-- Step 2: Update get_daily_topup_status to use NET amount (transactions.amount)
CREATE OR REPLACE FUNCTION public.get_daily_topup_status(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_today date := CURRENT_DATE;
  v_current_total bigint := 0;
  v_max_daily bigint := 300000;  -- 3,000 THB in satang (Wallet Credit)
  v_min_per_txn bigint := 50000; -- 500 THB in satang (Wallet Credit)
  v_result jsonb;
  v_backfilled_amount bigint;
BEGIN
  -- 1. Try to get existing tracking record
  SELECT total_amount_satang INTO v_current_total
  FROM private.daily_topup_tracking
  WHERE user_id = p_user_id AND topup_date = v_today;
  
  -- 2. SELF-HEALING: If no record (NULL), backfill from transactions table
  IF v_current_total IS NULL THEN
    -- 💎 FIX: Use transactions.amount directly (NET Wallet Credit)
    -- NOT metadata->>'charge_amount_satang' (GROSS Charge Amount)
    -- This aligns with user expectation: "I can top up 3000 THB/day" = wallet credit
    SELECT COALESCE(SUM(amount), 0)
    INTO v_backfilled_amount
    FROM transactions t
    JOIN wallets w ON t.wallet_id = w.id
    WHERE w.profile_id = p_user_id
      AND t.type = 'TOPUP'
      AND t.status = 'SUCCESS'
      AND DATE(t.created_at AT TIME ZONE 'Asia/Bangkok') = v_today;
      
    v_current_total := v_backfilled_amount;
    
    -- Persist this backfill for performance
    INSERT INTO private.daily_topup_tracking (user_id, topup_date, total_amount_satang)
    VALUES (p_user_id, v_today, v_current_total)
    ON CONFLICT (user_id, topup_date) 
    DO UPDATE SET total_amount_satang = GREATEST(
      private.daily_topup_tracking.total_amount_satang, 
      EXCLUDED.total_amount_satang
    );
  END IF;
  
  -- 3. Return Result (All values in satang, based on NET Wallet Credit)
  v_result := jsonb_build_object(
    'current_total', v_current_total,
    'max_daily', v_max_daily,
    'remaining_limit', GREATEST(0, v_max_daily - v_current_total),
    'min_per_transaction', v_min_per_txn,
    'is_limit_reached', v_current_total >= v_max_daily
  );
  
  RETURN v_result;
END;
$$;

-- Step 3: Ensure permissions
GRANT EXECUTE ON FUNCTION public.get_daily_topup_status(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_daily_topup_status(uuid) TO authenticated;
