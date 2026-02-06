-- ============================================================================
-- URGENT FIX: Daily Limit Truth - Transaction-First Approach
-- ============================================================================
-- PROBLEM: 
--   - get_daily_topup_status shows 600 THB but Activity Stream shows 520.33 THB
--   - The daily limit is calculated from tracking table which can be out of sync
--   - Need to ALWAYS use transactions as source of truth
-- 
-- SOLUTION:
--   - Always calculate daily usage directly from transactions table
--   - No reliance on tracking table for display (tracking used only for race-lock)
--   - Ensure timezone is Bangkok for both query and display
-- ============================================================================

-- Step 1: Delete tracking data to force recalculation
TRUNCATE TABLE private.daily_topup_tracking;

-- Step 2: Fix get_daily_topup_status - ALWAYS query from transactions
CREATE OR REPLACE FUNCTION public.get_daily_topup_status(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
    v_today date;
    v_current_total bigint := 0;
    v_max_daily bigint := 300000;  -- 3,000 THB in satang
    v_min_per_txn bigint := 50000; -- 500 THB in satang
BEGIN
    -- 🛡️ Force Bangkok Timezone for TODAY (Thailand Standard Time)
    v_today := (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Bangkok')::date;
    
    -- 💎 TRUTH: Always calculate from transactions directly
    -- This is the only true source of what user has topped up today
    SELECT COALESCE(SUM(t.amount), 0)
    INTO v_current_total
    FROM transactions t
    INNER JOIN wallets w ON t.wallet_id = w.id
    WHERE w.profile_id = p_user_id
      AND t.type = 'TOPUP'
      AND t.status = 'SUCCESS'
      -- 🛡️ Bangkok timezone comparison for transaction date
      AND (t.created_at AT TIME ZONE 'Asia/Bangkok')::date = v_today;

    RETURN jsonb_build_object(
        'current_total', v_current_total,
        'max_daily', v_max_daily,
        'remaining_limit', GREATEST(0, v_max_daily - v_current_total),
        'min_per_transaction', v_min_per_txn,
        'is_limit_reached', v_current_total >= v_max_daily,
        'server_date', v_today,
        'server_timestamp', CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Bangkok'
    );
END;
$$;

-- Step 3: Fix check_and_update_daily_topup - Query transactions, then lock tracking
-- This ensures we check the TRUE usage, not a potentially stale tracking value
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
    v_today date := (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Bangkok')::date;
    v_current_total bigint;
    v_max_daily bigint := 300000;
    v_remaining bigint;
BEGIN
    -- 🛡️ LOCK: First acquire advisory lock to prevent race conditions
    -- This blocks other concurrent topups for this user
    PERFORM pg_advisory_xact_lock(hashtext(p_user_id::text || v_today::text));
    
    -- 💎 TRUTH: Calculate current total from ACTUAL transactions
    SELECT COALESCE(SUM(t.amount), 0)
    INTO v_current_total
    FROM transactions t
    INNER JOIN wallets w ON t.wallet_id = w.id
    WHERE w.profile_id = p_user_id
      AND t.type = 'TOPUP'
      AND t.status = 'SUCCESS'
      AND (t.created_at AT TIME ZONE 'Asia/Bangkok')::date = v_today;
    
    v_remaining := v_max_daily - v_current_total;

    -- Check if this new amount would exceed limit
    IF p_amount_satang > v_remaining THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Daily top-up limit exceeded',
            'current_total', v_current_total,
            'requested_amount', p_amount_satang,
            'remaining_limit', v_remaining,
            'max_daily', v_max_daily
        );
    END IF;

    -- ✅ Approved - no need to update tracking here
    -- The tracking table is updated by the actual transaction insert
    -- We just return approval, the transaction itself is the truth
    
    RETURN jsonb_build_object(
        'success', true,
        'current_total', v_current_total,
        'requested_amount', p_amount_satang,
        'new_total', v_current_total + p_amount_satang,
        'remaining_limit', v_remaining - p_amount_satang,
        'max_daily', v_max_daily
    );
END;
$$;

-- Step 4: Grant permissions
GRANT EXECUTE ON FUNCTION public.get_daily_topup_status(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_daily_topup_status(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_and_update_daily_topup(uuid, bigint) TO service_role;

-- ============================================================================
-- NOTE: After deploying this migration, the daily limit display should 
-- correctly reflect the sum of transactions for today (Bangkok time).
-- ============================================================================
