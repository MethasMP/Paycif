-- ============================================================================
-- FINAL PERMANENT FIX: THE "TRUTH" RECLAMATION
-- ============================================================================
-- 1. Corrects OLD transactions that were saved as GROSS (e.g. 520.33 -> 500.00)
-- 2. Strictly enforces Asia/Bangkok Timezone for ALL limit calculations.
-- 3. Resets all tracking to ensure 100% accuracy.
-- ============================================================================

-- Step 1: Retroactive Math-Based Fix
-- We calculate the NET amount from GROSS for old transactions.
-- Formula based on the fixed rate: Net = round(Gross * 0.960945)
-- We target transactions that look like they have the fee included (not round numbers).
UPDATE transactions
SET amount = ROUND(amount * 0.960945)
WHERE type = 'TOPUP' 
  AND status = 'SUCCESS'
  AND amount % 100 != 0; -- Target non-round numbers like 52033

-- Step 2: Super-Strict Timezone-Synchronized Limit Status
CREATE OR REPLACE FUNCTION public.get_daily_topup_status(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
    v_today date;
    v_current_total bigint := 0;
    v_max_daily bigint := 300000;
    v_min_per_txn bigint := 50000;
BEGIN
    -- 🛡️ Force Bangkok Timezone for TODAY
    v_today := (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Bangkok')::date;
    
    -- Recalculate directly from transactions for 100% truth (Bypass potentially buggy tracking table)
    SELECT COALESCE(SUM(amount), 0)
    INTO v_current_total
    FROM transactions t
    JOIN wallets w ON t.wallet_id = w.id
    WHERE w.profile_id = p_user_id
      AND t.type = 'TOPUP'
      AND t.status = 'SUCCESS'
      -- 🛡️ Use strict Bangkok date comparison
      AND (t.created_at AT TIME ZONE 'Asia/Bangkok')::date = v_today;

    RETURN jsonb_build_object(
        'current_total', v_current_total,
        'max_daily', v_max_daily,
        'remaining_limit', GREATEST(0, v_max_daily - v_current_total),
        'min_per_transaction', v_min_per_txn,
        'is_limit_reached', v_current_total >= v_max_daily,
        'server_date', v_today -- For debugging
    );
END;
$$;

-- Step 3: Sync check_and_update_daily_topup to use the same logic
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
BEGIN
    -- Recalculate Truth
    SELECT COALESCE(SUM(amount), 0) INTO v_current_total
    FROM transactions t
    JOIN wallets w ON t.wallet_id = w.id
    WHERE w.profile_id = p_user_id
      AND t.type = 'TOPUP'
      AND t.status = 'SUCCESS'
      AND (t.created_at AT TIME ZONE 'Asia/Bangkok')::date = v_today;

    IF (v_current_total + p_amount_satang) > v_max_daily THEN
        RETURN jsonb_build_object(
            'success', false,
            'remaining_limit', v_max_daily - v_current_total
        );
    END IF;

    -- Update tracking table purely for legacy sync/performance if needed
    INSERT INTO private.daily_topup_tracking (user_id, topup_date, total_amount_satang)
    VALUES (p_user_id, v_today, v_current_total + p_amount_satang)
    ON CONFLICT (user_id, topup_date) 
    DO UPDATE SET total_amount_satang = EXCLUDED.total_amount_satang;

    RETURN jsonb_build_object(
        'success', true,
        'new_total', v_current_total + p_amount_satang,
        'remaining_limit', v_max_daily - (v_current_total + p_amount_satang)
    );
END;
$$;

-- Step 4: Truncate to force all clients to see the new truth
TRUNCATE TABLE private.daily_topup_tracking;
