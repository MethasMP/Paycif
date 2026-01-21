-- ============================================================================
-- PROCESS INBOUND TRANSACTION (Atomic Top-Up)
-- ============================================================================
-- Handles atomic balance credit after successful Opn (Omise) charge.
-- 
-- CALLED BY: inbound-handler Edge Function (Service Role)
-- ============================================================================

CREATE OR REPLACE FUNCTION process_inbound_transaction(
    p_user_id UUID,           -- Profile/Auth ID
    p_amount_satang BIGINT,
    p_provider TEXT,          -- 'omise'
    p_provider_txn_id TEXT,   -- 'chrg_test_...'
    p_reference_id TEXT,      -- Client UUID for idempotency
    p_description TEXT DEFAULT 'Top Up',
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS TABLE (
    transaction_id UUID,
    new_balance BIGINT,
    status_code INT,
    status_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_wallet_id UUID;
    v_current_balance BIGINT;
    v_wallet_status TEXT;
    v_new_balance BIGINT;
    v_transaction_id UUID;
    v_ledger_entry_id UUID;
    v_existing_txn_id UUID;
BEGIN
    -- =========================================================================
    -- STEP 0: Idempotency Check
    -- =========================================================================
    -- Check if we already processed this reference_id (Client UUID)
    SELECT id INTO v_existing_txn_id
    FROM transactions
    WHERE reference_id = p_reference_id;

    IF v_existing_txn_id IS NOT NULL THEN
        -- Transaction already exists, return success (idempotent)
        -- In a real scenario, we might want to return the actual previous result
        RETURN QUERY SELECT 
            v_existing_txn_id,
            (SELECT balance FROM wallets WHERE profile_id = p_user_id),
            200,
            'Transaction already processed (Idempotent)'::TEXT;
        RETURN;
    END IF;

    -- =========================================================================
    -- STEP 1: Get Wallet & Lock Row
    -- =========================================================================
    SELECT id, balance, COALESCE(status, 'active')
    INTO v_wallet_id, v_current_balance, v_wallet_status
    FROM wallets
    WHERE profile_id = p_user_id
    FOR UPDATE;

    IF v_wallet_id IS NULL THEN
        RETURN QUERY SELECT NULL::UUID, 0::BIGINT, 404, 'Wallet not found'::TEXT;
        RETURN;
    END IF;

    IF LOWER(v_wallet_status) != 'active' THEN
        RETURN QUERY SELECT NULL::UUID, 0::BIGINT, 403, 'Wallet is halted'::TEXT;
        RETURN;
    END IF;

    -- =========================================================================
    -- STEP 2: Calculate New Balance
    -- =========================================================================
    IF p_amount_satang <= 0 THEN
         RETURN QUERY SELECT NULL::UUID, 0::BIGINT, 400, 'Amount must be positive'::TEXT;
         RETURN;
    END IF;

    v_new_balance := v_current_balance + p_amount_satang;
    v_transaction_id := gen_random_uuid();
    v_ledger_entry_id := gen_random_uuid();

    -- =========================================================================
    -- STEP 3: Update Wallet Balance
    -- =========================================================================
    UPDATE wallets
    SET balance = v_new_balance,
        updated_at = NOW()
    WHERE id = v_wallet_id;

    -- =========================================================================
    -- STEP 4: Insert Transaction Record
    -- =========================================================================
    INSERT INTO transactions (
        id,
        reference_id, -- Used for idempotency
        description,
        status,
        settlement_status, -- Important for Opn (7-day hold)
        provider_metadata,
        wallet_id,
        type,           -- TOPUP for inbound, PAYOUT for outbound
        amount,         -- Store amount for transaction list display
        created_at
    ) VALUES (
        v_transaction_id,
        p_reference_id,
        p_description,
        'SUCCESS',      -- We only call this RPC if Opn charge succeeded
        'UNSETTLED',    -- Default Opn state
        p_metadata || jsonb_build_object(
            'provider', p_provider,
            'provider_txn_id', p_provider_txn_id,
            'amount_satang', p_amount_satang
        ),
        v_wallet_id,
        'TOPUP',        -- Explicitly set type for correct frontend display
        p_amount_satang, -- Store amount for transaction list
        NOW()
    );

    -- =========================================================================
    -- STEP 5: Create Ledger Entry (CREDIT)
    -- =========================================================================
    INSERT INTO ledger_entries (
        id,
        transaction_id,
        wallet_id,
        amount,
        type, -- CREDIT
        currency,
        description,
        balance_after,
        created_at
    ) VALUES (
        v_ledger_entry_id,
        v_transaction_id,
        v_wallet_id,
        p_amount_satang, -- Positive for Credit
        'CREDIT',
        'THB',
        p_description,
        v_new_balance,
        NOW()
    );

    -- =========================================================================
    -- STEP 6: Outbox for Notification
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
        'TOPUP_COMPLETED',
        jsonb_build_object(
            'user_id', p_user_id,
            'amount_satang', p_amount_satang,
            'provider_txn_id', p_provider_txn_id
        ),
        'PENDING',
        0,
        NOW()
    );

    -- =========================================================================
    -- STEP 7: Return Success
    -- =========================================================================
    RETURN QUERY SELECT 
        v_transaction_id,
        v_new_balance,
        200,
        'Top-up successful'::TEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION process_inbound_transaction TO service_role;
-- We do NOT grant to authenticated because this function trusts the caller implicitly 
-- regarding the payment success. It should ONLY be called by the Edge Function.
