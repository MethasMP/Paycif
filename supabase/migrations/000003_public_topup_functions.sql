-- ============================================================================
-- MOVE DAILY TOPUP FUNCTIONS TO PUBLIC
-- Reason: PostgREST (RPC) only exposes the 'public' schema by default.
-- Functions in 'private' schema cannot be called via supabase.rpc().
-- ============================================================================

-- 1. Drop old private functions to avoid confusion
DROP FUNCTION IF EXISTS private.check_and_update_daily_topup(uuid, bigint);
DROP FUNCTION IF EXISTS private.get_daily_topup_status(uuid);

-- 2. Create check_and_update_daily_topup in PUBLIC
-- 🛡️ RACE CONDITION SAFE: Uses row-level locking (FOR UPDATE)
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
  v_today date := CURRENT_DATE;
  v_current_total bigint;
  v_max_daily bigint := 300000; -- 3,000 THB in satang
  v_remaining bigint;
  v_result jsonb;
  v_record_id uuid;
BEGIN
  -- 🛡️ CRITICAL: Lock the row for this user+date to prevent race conditions
  
  -- First, try to get existing record with exclusive lock
  SELECT id, total_amount_satang 
  INTO v_record_id, v_current_total
  FROM private.daily_topup_tracking
  WHERE user_id = p_user_id AND topup_date = v_today
  FOR UPDATE;
  
  -- If no record exists, create one with lock
  IF v_record_id IS NULL THEN
    INSERT INTO private.daily_topup_tracking (user_id, topup_date, total_amount_satang)
    VALUES (p_user_id, v_today, 0)
    RETURNING id, total_amount_satang INTO v_record_id, v_current_total;
  END IF;
  
  v_remaining := v_max_daily - v_current_total;
  
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
  
  -- Update the locked row
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

-- 3. Create get_daily_topup_status in PUBLIC
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
BEGIN
  SELECT total_amount_satang INTO v_current_total
  FROM private.daily_topup_tracking
  WHERE user_id = p_user_id AND topup_date = v_today;
  
  IF v_current_total IS NULL THEN
    v_current_total := 0;
  END IF;
  
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

-- 4. Grant Permissions
GRANT EXECUTE ON FUNCTION public.check_and_update_daily_topup TO service_role;
GRANT EXECUTE ON FUNCTION public.get_daily_topup_status TO service_role;
-- We can also grant to authenticated if we want direct client access, 
-- but we are proxying via Edge Function (adminClient), so service_role is sufficient.
