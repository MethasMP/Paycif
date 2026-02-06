-- ============================================================================
-- FIX: Transaction Amount Truth - Always record INTENDED (Net) amount
-- ============================================================================
-- Even if the backend sends Gross amount for some reason, we extract the 
-- wallet_amount_satang from metadata as the source of truth for:
-- 1. User Balance
-- 2. Transaction History (What user sees)
-- 3. Daily Limits
-- ============================================================================

CREATE OR REPLACE FUNCTION process_inbound_transaction(
    p_user_id UUID,
    p_amount_satang BIGINT, -- Received from backend
    p_provider TEXT,
    p_provider_txn_id TEXT,
    p_reference_id TEXT,
    p_description TEXT DEFAULT 'Wallet Top Up',
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
    v_new_balance BIGINT;
    v_transaction_id UUID;
    v_wallet_amount_satang BIGINT;
BEGIN
    -- Correct description if generic
    IF p_description IS NULL OR p_description = 'Top Up' OR p_description LIKE 'TopUp:%' THEN
        p_description := 'Wallet Top Up';
    END IF;

    -- 💎 SOURCE OF TRUTH: 
    -- 1. Try to get intended net amount from metadata (set by backend logic)
    -- 2. Fallback to p_amount_satang
    v_wallet_amount_satang := COALESCE(
        (p_metadata->>'wallet_amount_satang')::bigint, 
        p_amount_satang
    );

    -- Idempotency check 
    SELECT id INTO v_transaction_id FROM transactions WHERE reference_id = p_reference_id;
    IF v_transaction_id IS NOT NULL THEN
        RETURN QUERY SELECT v_transaction_id, (SELECT balance FROM wallets WHERE profile_id = p_user_id), 200, 'Success (Idempotent)'::TEXT;
        RETURN;
    END IF;

    -- Lock Wallet
    SELECT id, balance INTO v_wallet_id, v_current_balance FROM wallets WHERE profile_id = p_user_id FOR UPDATE;
    
    IF v_wallet_id IS NULL THEN
        RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
    END IF;

    -- Credit Wallet with NET
    v_new_balance := v_current_balance + v_wallet_amount_satang;
    v_transaction_id := gen_random_uuid();
    
    UPDATE wallets SET balance = v_new_balance, updated_at = NOW() WHERE id = v_wallet_id;

    -- 💎 FIX: Record the NET amount in the amount column.
    -- This ensures History, Activity Stream, and Daily Limits (which query this table)
    -- always show the intended top-up amount without gateway fees.
    INSERT INTO transactions (
        id, reference_id, description, status, settlement_status, 
        provider_metadata, wallet_id, type, amount, created_at
    ) VALUES (
        v_transaction_id, p_reference_id, p_description, 'SUCCESS', 'UNSETTLED',
        p_metadata || jsonb_build_object(
            'provider', p_provider, 
            'provider_txn_id', p_provider_txn_id,
            'recorded_as', 'NET'
        ),
        v_wallet_id, 'TOPUP', v_wallet_amount_satang, NOW()
    );

    -- Ledger (Accounting)
    INSERT INTO ledger_entries (
        id, transaction_id, wallet_id, amount, type, currency, description, balance_after, created_at
    ) VALUES (
        gen_random_uuid(), v_transaction_id, v_wallet_id, v_wallet_amount_satang, 
        'CREDIT', 'THB', p_description, v_new_balance, NOW()
    );

    RETURN QUERY SELECT v_transaction_id, v_new_balance, 200, 'Top-up successful'::TEXT;
END;
$$;

-- 💎 REPAIR: Retroactively fix any existing transactions that stored Gross instead of Net
-- This will fix the Daily Limit display and Activity Stream for previous top-ups.
UPDATE transactions 
SET amount = (provider_metadata->>'wallet_amount_satang')::bigint
WHERE type = 'TOPUP' 
  AND status = 'SUCCESS'
  AND (provider_metadata->>'wallet_amount_satang') IS NOT NULL
  AND amount != (provider_metadata->>'wallet_amount_satang')::bigint;

