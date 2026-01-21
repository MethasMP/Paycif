-- ============================================================================
-- PROCESS PAYOUT REQUEST (Atomic Balance Deduction + Transaction Creation)
-- ============================================================================
-- This function is the "Brain" that handles atomic operations for payout.
-- 
-- SCHEMA NOTES (based on actual Supabase tables):
-- - wallets: Uses `profile_id` (not user_id), balance in satang, status='active'
-- - transactions: High-level record (no amount/type here)
-- - ledger_entries: Contains actual amount, type (DEBIT/CREDIT)
-- - transaction_outbox: Requires `event_type` field
-- ============================================================================

CREATE OR REPLACE FUNCTION process_payout_request(
    p_user_id UUID,           -- This is the profile_id (user's profile)
    p_wallet_id UUID,
    p_amount_satang BIGINT,
    p_target_type TEXT,       -- MOBILE, NATID, EWALLET
    p_target_value TEXT,
    p_description TEXT DEFAULT 'Payout'
)
RETURNS TABLE (
    transaction_id UUID,
    status_code INT,
    status_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_transaction_id UUID;
    v_ledger_entry_id UUID;
    v_current_balance BIGINT;
    v_wallet_owner UUID;
    v_wallet_status TEXT;
    v_new_balance BIGINT;
BEGIN
    -- =========================================================================
    -- STEP 1: Validate wallet exists and belongs to user (profile_id)
    -- =========================================================================
    SELECT profile_id, balance, COALESCE(status, 'active')
    INTO v_wallet_owner, v_current_balance, v_wallet_status
    FROM wallets
    WHERE id = p_wallet_id
    FOR UPDATE;  -- Lock the row for atomic operation

    IF v_wallet_owner IS NULL THEN
        RETURN QUERY SELECT 
            NULL::UUID,
            404,
            'Wallet not found'::TEXT;
        RETURN;
    END IF;

    -- Check ownership (profile_id must match)
    IF v_wallet_owner != p_user_id THEN
        RETURN QUERY SELECT 
            NULL::UUID,
            403,
            'Wallet does not belong to user'::TEXT;
        RETURN;
    END IF;

    -- Check wallet is active (lowercase 'active' based on schema)
    IF LOWER(v_wallet_status) != 'active' THEN
        RETURN QUERY SELECT 
            NULL::UUID,
            403,
            'Wallet is halted or inactive'::TEXT;
        RETURN;
    END IF;

    -- =========================================================================
    -- STEP 2: Validate amount
    -- =========================================================================
    IF p_amount_satang <= 0 THEN
        RETURN QUERY SELECT 
            NULL::UUID,
            400,
            'Amount must be positive'::TEXT;
        RETURN;
    END IF;

    -- =========================================================================
    -- STEP 3: Check sufficient balance
    -- =========================================================================
    IF v_current_balance < p_amount_satang THEN
        RETURN QUERY SELECT 
            NULL::UUID,
            400,
            'Insufficient balance'::TEXT;
        RETURN;
    END IF;

    -- =========================================================================
    -- STEP 4: Validate target type
    -- =========================================================================
    IF p_target_type NOT IN ('MOBILE', 'NATID', 'EWALLET') THEN
        RETURN QUERY SELECT 
            NULL::UUID,
            400,
            'Invalid target type. Must be MOBILE, NATID, or EWALLET'::TEXT;
        RETURN;
    END IF;

    -- =========================================================================
    -- STEP 5: Generate IDs
    -- =========================================================================
    v_transaction_id := gen_random_uuid();
    v_ledger_entry_id := gen_random_uuid();
    v_new_balance := v_current_balance - p_amount_satang;

    -- =========================================================================
    -- STEP 6: Deduct balance atomically
    -- =========================================================================
    UPDATE wallets
    SET balance = v_new_balance,
        updated_at = NOW()
    WHERE id = p_wallet_id;

    -- =========================================================================
    -- STEP 7: Create transaction record (based on actual schema)
    -- Note: transactions table has: id, reference_id, description, status,
    --       settlement_status, gateway_fee, provider_metadata, wallet_id
    -- =========================================================================
    INSERT INTO transactions (
        id,
        reference_id,
        description,
        status,
        provider_metadata,
        wallet_id,
        created_at
    ) VALUES (
        v_transaction_id,
        'PAYOUT-' || v_transaction_id::TEXT,
        p_description,
        'PENDING',
        jsonb_build_object(
            'target_type', p_target_type,
            'target_value', p_target_value,
            'amount_satang', p_amount_satang,
            'initiated_at', NOW()
        ),
        p_wallet_id,
        NOW()
    );

    -- =========================================================================
    -- STEP 8: Create ledger entry (DEBIT - money going out)
    -- Note: ledger_entries has: id, transaction_id, wallet_id, amount, type,
    --       currency, description, balance_after
    -- =========================================================================
    INSERT INTO ledger_entries (
        id,
        transaction_id,
        wallet_id,
        amount,
        type,
        currency,
        description,
        balance_after,
        created_at
    ) VALUES (
        v_ledger_entry_id,
        v_transaction_id,
        p_wallet_id,
        -p_amount_satang,  -- Negative for debit (money going out)
        'DEBIT',
        'THB',
        p_description,
        v_new_balance,
        NOW()
    );

    -- =========================================================================
    -- STEP 9: Create outbox entry for async processing
    -- Note: transaction_outbox has: id, transaction_id, event_type, payload,
    --       status, retry_count, last_attempt_at, error_message
    -- =========================================================================
    INSERT INTO transaction_outbox (
        id,
        transaction_id,
        event_type,
        payload,
        status,
        retry_count,
        created_at
    ) VALUES (
        gen_random_uuid(),
        v_transaction_id,
        'PAYOUT_REQUESTED',
        jsonb_build_object(
            'user_id', p_user_id,
            'wallet_id', p_wallet_id,
            'amount_satang', p_amount_satang,
            'target_type', p_target_type,
            'target_value', p_target_value,
            'description', p_description
        ),
        'PENDING',
        0,
        NOW()
    );

    -- =========================================================================
    -- STEP 10: Return success
    -- =========================================================================
    RETURN QUERY SELECT 
        v_transaction_id,
        200,
        'Payout request created successfully'::TEXT;
END;
$$;

-- Grant execute permission to authenticated users and service role
GRANT EXECUTE ON FUNCTION process_payout_request TO authenticated;
GRANT EXECUTE ON FUNCTION process_payout_request TO service_role;

COMMENT ON FUNCTION process_payout_request IS 
'Atomic payout request processor. Validates wallet, deducts balance, creates transaction, ledger entry, and outbox entry. Compatible with actual Supabase schema.';
