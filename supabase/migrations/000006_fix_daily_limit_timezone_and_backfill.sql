-- ============================================================================
-- FIX DAILY LIMIT: TIMEZONE + BACKFILL FOR BOTH FUNCTIONS
-- ============================================================================
-- Problem 1: check_and_update_daily_topup doesn't have backfill logic
-- Problem 2: Timezone mismatch - using UTC CURRENT_DATE vs Bangkok transactions
-- 
-- Solution: Sync both functions to use Bangkok timezone and backfill from
--           transactions.amount (NET wallet credit)
-- ============================================================================

-- Step 1: Clear tracking data again (force recalculation)
TRUNCATE TABLE private.daily_topup_tracking;

-- Step 2: Fix check_and_update_daily_topup with BACKFILL + TIMEZONE
CREATE OR REPLACE FUNCTION public.check_and_update_daily_topup(
  p_user_id uuid,
  p_amount_satang bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Bangkok')::date; -- 🛡️ Use Bangkok timezone
  v_current_total bigint;
  v_max_daily bigint := 300000; -- 3,000 THB in satang (Wallet Credit)
  v_remaining bigint;
  v_result jsonb;
  v_record_id uuid;
  v_backfilled_amount bigint;
BEGIN
  -- 🛡️ CRITICAL: Lock the row for this user+date to prevent race conditions
  
  -- First, try to get existing record with exclusive lock
  SELECT id, total_amount_satang 
  INTO v_record_id, v_current_total
  FROM private.daily_topup_tracking
  WHERE user_id = p_user_id AND topup_date = v_today
  FOR UPDATE;
  
  -- If no record exists, BACKFILL from transactions then create
  IF v_record_id IS NULL THEN
    -- 💎 BACKFILL: Calculate total from transactions.amount (NET Wallet Credit)
    SELECT COALESCE(SUM(amount), 0)
    INTO v_backfilled_amount
    FROM transactions t
    JOIN wallets w ON t.wallet_id = w.id
    WHERE w.profile_id = p_user_id
      AND t.type = 'TOPUP'
      AND t.status = 'SUCCESS'
      AND (t.created_at AT TIME ZONE 'Asia/Bangkok')::date = v_today;
    
    -- Insert with backfilled amount
    INSERT INTO private.daily_topup_tracking (user_id, topup_date, total_amount_satang)
    VALUES (p_user_id, v_today, v_backfilled_amount)
    RETURNING id, total_amount_satang INTO v_record_id, v_current_total;
  END IF;
  
  v_remaining := v_max_daily - v_current_total;
  
  -- Check if new top-up would exceed limit
  IF p_amount_satang > v_remaining THEN
    v_result := jsonb_build_object(
      'success', false,
      'error', 'Daily top-up limit exceeded',
      'current_total', v_current_total,
      'requested_amount', p_amount_satang,
      'remaining_limit', v_remaining,
      'max_daily', v_max_daily
    );
    RETURN v_result;
  END IF;
  
  -- Update the locked row with new amount
  UPDATE private.daily_topup_tracking
  SET total_amount_satang = total_amount_satang + p_amount_satang,
      updated_at = now()
  WHERE id = v_record_id;
  
  v_result := jsonb_build_object(
    'success', true,
    'previous_total', v_current_total,
    'new_total', v_current_total + p_amount_satang,
    'remaining_limit', v_remaining - p_amount_satang,
    'max_daily', v_max_daily
  );
  
  RETURN v_result;
END;
$$;

-- Step 3: Fix get_daily_topup_status with correct TIMEZONE
CREATE OR REPLACE FUNCTION public.get_daily_topup_status(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Bangkok')::date; -- 🛡️ Use Bangkok timezone
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
    -- With correct Bangkok timezone
    SELECT COALESCE(SUM(amount), 0)
    INTO v_backfilled_amount
    FROM transactions t
    JOIN wallets w ON t.wallet_id = w.id
    WHERE w.profile_id = p_user_id
      AND t.type = 'TOPUP'
      AND t.status = 'SUCCESS'
      AND (t.created_at AT TIME ZONE 'Asia/Bangkok')::date = v_today;
      
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

-- Step 4: Ensure permissions
GRANT EXECUTE ON FUNCTION public.check_and_update_daily_topup(uuid, bigint) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_daily_topup_status(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_daily_topup_status(uuid) TO authenticated;
