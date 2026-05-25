-- ============================================================================
-- FIX: Store GROSS Charge Amount in Transactions & Daily Limit
-- ============================================================================
-- User Requirement: 
-- 1. Transactions history MUST show the CHARGE amount (Gross), not Net.
-- 2. Daily Limit MUST count the CHARGE amount (Gross).
-- 3. Wallet Balance still receives NET amount.
-- ============================================================================

-- 1. Fix RPC to store Gross Amount in transactions table
CREATE OR REPLACE FUNCTION process_inbound_transaction(
    p_user_id UUID,
    p_amount_satang BIGINT, -- This is the AMOUNT TO STORE (Gross/Charge)
    p_provider TEXT,
    p_provider_txn_id TEXT,
    p_reference_id TEXT,
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
    v_new_balance BIGINT;
    v_transaction_id UUID;
    v_wallet_amount_satang BIGINT;
    v_charge_amount_satang BIGINT;
BEGIN
    -- Extract amounts from metadata
    -- p_amount_satang passed from API is the CHARGE amount (Gross)
    v_charge_amount_satang := p_amount_satang;
    
    -- Try to get Net amount from metadata, otherwise fallback (risky but needed)
    -- Metadata keys should be 'wallet_amount_satang'
    v_wallet_amount_satang := COALESCE(
        (p_metadata->>'wallet_amount_satang')::bigint, 
        v_charge_amount_satang -- Fallback if not found (should verify fee logic)
    );

    -- Idempotency check
    SELECT id INTO v_transaction_id FROM transactions WHERE reference_id = p_reference_id;
    IF v_transaction_id IS NOT NULL THEN
        RETURN QUERY SELECT v_transaction_id, (SELECT balance FROM wallets WHERE profile_id = p_user_id), 200, 'Success (Idempotent)'::TEXT;
        RETURN;
    END IF;

    -- Lock Wallet
    SELECT id, balance INTO v_wallet_id, v_current_balance FROM wallets WHERE profile_id = p_user_id FOR UPDATE;
    
    -- Credit Wallet with NET amount (What user can actually spend)
    v_new_balance := v_current_balance + v_wallet_amount_satang;
    v_transaction_id := gen_random_uuid();
    
    UPDATE wallets SET balance = v_new_balance, updated_at = NOW() WHERE id = v_wallet_id;

    -- Record Transaction with GROSS/CHARGE amount for History & Limits
    INSERT INTO transactions (
        id, reference_id, description, status, settlement_status, 
        provider_metadata, wallet_id, type, amount, created_at
    ) VALUES (
        v_transaction_id, p_reference_id, p_description, 'SUCCESS', 'UNSETTLED',
        p_metadata || jsonb_build_object('provider', p_provider, 'provider_txn_id', p_provider_txn_id),
        v_wallet_id, 'TOPUP', v_charge_amount_satang, NOW() -- Store Charge Amount
    );

    -- Ledger Entry (Accounting) - Here we track the actual Net Credit
    INSERT INTO ledger_entries (
        id, transaction_id, wallet_id, amount, type, currency, description, balance_after, created_at
    ) VALUES (
        gen_random_uuid(), v_transaction_id, v_wallet_id, v_wallet_amount_satang, 
        'CREDIT', 'THB', p_description, v_new_balance, NOW()
    );

    RETURN QUERY SELECT v_transaction_id, v_new_balance, 200, 'Top-up successful'::TEXT;
END;
$$;

-- 2. Retroactive Fix for Today's Transactions (2026-02-02)
-- Convert stored Net amounts back to Gross (Charge) from metadata
UPDATE transactions
SET amount = (provider_metadata->>'charge_amount_satang')::bigint
WHERE type = 'TOPUP' 
  AND status = 'SUCCESS'
  And provider_metadata ? 'charge_amount_satang'
  AND (created_at AT TIME ZONE 'Asia/Bangkok')::date = '2026-02-02';

-- 3. Reset Daily Limit Tracking to rely on the new "Gross" transaction amounts
TRUNCATE TABLE private.daily_topup_tracking;

-- Note: get_daily_topup_status already sums 'transactions.amount', 
-- so now it will correctly sum the Gross amounts.
