-- ============================================================================
-- HARDEN DAILY LIMITS: 3,000 THB Max, 500 THB Min
-- ============================================================================

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
    v_max_daily bigint := 300000;  -- 3,000 THB in satang
    v_min_per_txn bigint := 50000; -- 500 THB in satang
    v_remaining bigint;
BEGIN
    -- 🛡️ Step 1: Minimum Check
    IF p_amount_satang < v_min_per_txn THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Minimum top-up is ฿' || (v_min_per_txn / 100)::text,
            'requested_amount', p_amount_satang,
            'min_required', v_min_per_txn
        );
    END IF;

    -- 🛡️ Step 2: Advisory Lock (Per User/Day)
    PERFORM pg_advisory_xact_lock(hashtext(p_user_id::text || v_today::text));
    
    -- 💎 Step 3: Calculate TRUE Current Total (Source of Truth: Transactions)
    SELECT COALESCE(SUM(t.amount), 0)
    INTO v_current_total
    FROM transactions t
    INNER JOIN wallets w ON t.wallet_id = w.id
    WHERE w.profile_id = p_user_id
      AND t.type = 'TOPUP'
      AND t.status = 'SUCCESS'
      AND (t.created_at AT TIME ZONE 'Asia/Bangkok')::date = v_today;
    
    v_remaining := v_max_daily - v_current_total;

    -- 🛡️ Step 4: Maximum Check
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
