-- ============================================================================
-- HARDEN DAILY LIMITS: 3,000 THB Max, 500 THB Min with Idempotency & Rollback
-- ============================================================================

-- Table to track specific reservations to ensure RPC idempotency
CREATE TABLE IF NOT EXISTS private.topup_reservations (
    reference_id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount_satang BIGINT NOT NULL,
    status TEXT NOT NULL DEFAULT 'RESERVED', -- RESERVED, COMMITTED, ROLLED_BACK
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_topup_reservations_user_status ON private.topup_reservations(user_id, status);

-- Drop old versions to avoid overloading confusion
DROP FUNCTION IF EXISTS public.check_and_update_daily_topup(uuid, bigint);

CREATE OR REPLACE FUNCTION public.check_and_update_daily_topup(
  p_user_id uuid,
  p_amount_satang bigint,
  p_reference_id text
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
    v_min_per_txn bigint := 2000;  -- 20 THB in satang (Pay-Per-Use ready)
    v_remaining bigint;
    v_existing_status text;
BEGIN
    -- 🛡️ Step 0: Idempotency Check (RPC Level)
    SELECT status INTO v_existing_status
    FROM private.topup_reservations
    WHERE reference_id = p_reference_id;

    IF v_existing_status IS NOT NULL THEN
        -- If already reserved or committed, treat as success (idempotent)
        -- We don't deduct again.
        SELECT total_amount_satang INTO v_current_total
        FROM private.daily_topup_tracking
        WHERE user_id = p_user_id AND topup_date = v_today;

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Already reserved (Idempotent)',
            'current_total', v_current_total,
            'requested_amount', p_amount_satang,
            'remaining_limit', v_max_daily - v_current_total,
            'max_daily', v_max_daily
        );
    END IF;

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
    
    -- 🛡️ Step 3: Atomic update on tracking table
    -- First, ensure a row exists for today
    INSERT INTO private.daily_topup_tracking (user_id, topup_date, total_amount_satang)
    VALUES (p_user_id, v_today, 0)
    ON CONFLICT (user_id, topup_date) DO NOTHING;

    -- Update with row-level lock and limit check in one statement
    UPDATE private.daily_topup_tracking
    SET total_amount_satang = total_amount_satang + p_amount_satang,
        updated_at = NOW()
    WHERE user_id = p_user_id
      AND topup_date = v_today
      AND total_amount_satang + p_amount_satang <= v_max_daily
    RETURNING total_amount_satang INTO v_current_total;

    -- If update failed (due to limit), get current total for error message
    IF NOT FOUND THEN
        SELECT total_amount_satang INTO v_current_total
        FROM private.daily_topup_tracking
        WHERE user_id = p_user_id AND topup_date = v_today;

        v_remaining := v_max_daily - v_current_total;

        RETURN jsonb_build_object(
            'success', false,
            'error', 'Daily top-up limit exceeded',
            'current_total', v_current_total,
            'requested_amount', p_amount_satang,
            'remaining_limit', v_remaining,
            'max_daily', v_max_daily
        );
    END IF;
    
    -- 🛡️ Step 4: Record Reservation
    INSERT INTO private.topup_reservations (reference_id, user_id, amount_satang, status)
    VALUES (p_reference_id, p_user_id, p_amount_satang, 'RESERVED');

    v_remaining := v_max_daily - v_current_total;

    RETURN jsonb_build_object(
        'success', true,
        'current_total', v_current_total - p_amount_satang,
        'requested_amount', p_amount_satang,
        'new_total', v_current_total,
        'remaining_limit', v_remaining,
        'max_daily', v_max_daily
    );
END;
$$;

-- ============================================================================
-- COMMIT RESERVATION LOGIC (For inbound transactions)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.commit_topup_reservation(
    p_reference_id TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE private.topup_reservations
    SET status = 'COMMITTED',
        updated_at = NOW()
    WHERE reference_id = p_reference_id;
END;
$$;

-- Function to rollback limit if payment fails
CREATE OR REPLACE FUNCTION public.rollback_daily_topup(
  p_user_id uuid,
  p_reference_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
    v_today date := (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Bangkok')::date;
    v_amount_satang bigint;
    v_status text;
BEGIN
    -- 🛡️ Advisory Lock
    PERFORM pg_advisory_xact_lock(hashtext(p_user_id::text || v_today::text));

    -- Check if reservation exists and is in 'RESERVED' status
    SELECT amount_satang, status INTO v_amount_satang, v_status
    FROM private.topup_reservations
    WHERE reference_id = p_reference_id AND user_id = p_user_id;

    IF v_status = 'RESERVED' THEN
        -- Rollback the amount in tracking table
        UPDATE private.daily_topup_tracking
        SET total_amount_satang = GREATEST(0, total_amount_satang - v_amount_satang),
            updated_at = NOW()
        WHERE user_id = p_user_id AND topup_date = v_today;

        -- Update reservation status
        UPDATE private.topup_reservations
        SET status = 'ROLLED_BACK',
            updated_at = NOW()
        WHERE reference_id = p_reference_id;

        RETURN jsonb_build_object('success', true, 'message', 'Limit rolled back');
    END IF;

    RETURN jsonb_build_object('success', false, 'message', 'Reservation not found or already processed', 'status', v_status);
END;
$$;
