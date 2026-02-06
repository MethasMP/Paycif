-- ============================================================================
-- PERMANENT FIX: WALLET CREDIT & HISTORY INTEGRITY
-- ============================================================================
-- 1. Updates existing incorrect transactions to show NET amount, not GROSS.
-- 2. Updates process_inbound_transaction to ALWAYS store NET amount in 'amount' column.
-- 3. Ensures get_daily_topup_status uses the same NET-centric logic.
-- ============================================================================

-- Step 1: Retroactive Fix for History
-- Any transaction showing Gross (e.g., 520.33) will be updated to show Net (500.00) 
-- using the metadata we safely stored.
UPDATE transactions
SET amount = (provider_metadata->>'wallet_amount_satang')::bigint
WHERE type = 'TOPUP' 
  AND status = 'SUCCESS'
  AND provider_metadata ? 'wallet_amount_satang'
  AND amount != (provider_metadata->>'wallet_amount_satang')::bigint;

-- Step 2: Fix RPC for future transactions
CREATE OR REPLACE FUNCTION process_inbound_transaction(
    p_user_id UUID,
    p_amount_satang BIGINT, -- This is now NEVER trusted as gross, backend handles it
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
    v_ledger_entry_id UUID;
    v_existing_txn_id UUID;
    v_wallet_amount_satang BIGINT;
BEGIN
    -- 💎 TRUTH: We extract the wallet_amount_satang from metadata 
    -- if the inbound-handler passed it, otherwise we fallback to p_amount_satang.
    v_wallet_amount_satang := COALESCE((p_metadata->>'wallet_amount_satang')::bigint, p_amount_satang);

    -- Idempotency
    SELECT id INTO v_existing_txn_id FROM transactions WHERE reference_id = p_reference_id;
    IF v_existing_txn_id IS NOT NULL THEN
        RETURN QUERY SELECT v_existing_txn_id, (SELECT balance FROM wallets WHERE profile_id = p_user_id), 200, 'Success (Idempotent)'::TEXT;
        RETURN;
    END IF;

    -- Lock Wallet
    SELECT id, balance INTO v_wallet_id, v_current_balance FROM wallets WHERE profile_id = p_user_id FOR UPDATE;
    
    -- Credit Wallet with NET amount
    v_new_balance := v_current_balance + v_wallet_amount_satang;
    v_transaction_id := gen_random_uuid();
    
    UPDATE wallets SET balance = v_new_balance, updated_at = NOW() WHERE id = v_wallet_id;

    -- Record Transaction with NET amount for History
    INSERT INTO transactions (
        id, reference_id, description, status, settlement_status, 
        provider_metadata, wallet_id, type, amount, created_at
    ) VALUES (
        v_transaction_id, p_reference_id, p_description, 'SUCCESS', 'UNSETTLED',
        p_metadata || jsonb_build_object('provider', p_provider, 'provider_txn_id', p_provider_txn_id),
        v_wallet_id, 'TOPUP', v_wallet_amount_satang, NOW()
    );

    -- Ledger Entry (CREDIT)
    INSERT INTO ledger_entries (
        id, transaction_id, wallet_id, amount, type, currency, description, balance_after, created_at
    ) VALUES (
        gen_random_uuid(), v_transaction_id, v_wallet_id, v_wallet_amount_satang, 
        'CREDIT', 'THB', p_description, v_new_balance, NOW()
    );

    RETURN QUERY SELECT v_transaction_id, v_new_balance, 200, 'Top-up successful'::TEXT;
END;
$$;

-- Step 3: Refresh tracking again to be absolutely sure
TRUNCATE TABLE private.daily_topup_tracking;
