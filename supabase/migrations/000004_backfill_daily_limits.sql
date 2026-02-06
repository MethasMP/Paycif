-- ============================================================================
-- SELF-HEALING BACKFILL MIGRATION
-- ============================================================================
-- Modifies get_daily_topup_status to automatically calculate and backfill
-- the daily total from the transactions table if no tracking record exists.
-- This fixes the "missing history" issue for top-ups done before this feature.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_daily_topup_status(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
  v_today date := CURRENT_DATE;
  v_current_total bigint := 0;
  v_max_daily bigint := 300000;
  v_min_per_txn bigint := 50000;
  v_result jsonb;
  v_backfilled_amount bigint;
BEGIN
  -- 1. Try to get existing tracking record
  SELECT total_amount_satang INTO v_current_total
  FROM private.daily_topup_tracking
  WHERE user_id = p_user_id AND topup_date = v_today;
  
  -- 2. SELF-HEALING: If no record (NULL), backfill from transactions table
  IF v_current_total IS NULL THEN
    -- Calculate total `amount_satang` charged today from metadata.
    -- We use metadata->'charge_amount_satang' because 'amount' column stores NET wallet credit.
    -- If metadata is missing, fallback to 'amount' (better than 0).
    SELECT COALESCE(SUM(
      COALESCE((provider_metadata->>'charge_amount_satang')::bigint, amount)
    ), 0)
    INTO v_backfilled_amount
    FROM transactions t
    JOIN wallets w ON t.wallet_id = w.id
    WHERE w.profile_id = p_user_id
      AND t.type = 'TOPUP'
      AND t.status = 'SUCCESS'
      AND DATE(t.created_at AT TIME ZONE 'UTC') = v_today; -- Assuming server time is UTC or consistent
      
    v_current_total := v_backfilled_amount;
    
    -- Optional: Persist this backfill so we don't recalculate every time
    -- We use ON CONFLICT DO NOTHING purely for safety against race conditions
    INSERT INTO private.daily_topup_tracking (user_id, topup_date, total_amount_satang)
    VALUES (p_user_id, v_today, v_current_total)
    ON CONFLICT (user_id, topup_date) 
    DO UPDATE SET total_amount_satang = GREATEST(private.daily_topup_tracking.total_amount_satang, EXCLUDED.total_amount_satang);
  END IF;
  
  -- 3. Return Result
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

-- Grant permissions explicitly again to be safe
GRANT EXECUTE ON FUNCTION public.get_daily_topup_status(uuid) TO service_role;
