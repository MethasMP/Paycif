-- ============================================================================
-- MANUAL RECONCILIATION: Recover Missing Transaction
-- ============================================================================

DO $$
DECLARE
    v_user_id UUID;
    v_wallet_id UUID;
    v_charge_id TEXT := 'chrg_test_66kmdq346ijf0mxgpza';
    v_ref_id TEXT := '1769965857202'; -- From screenshot
    v_charge_amount BIGINT := 10000; -- 100.00 THB
    v_wallet_amount BIGINT := 9609;  -- 96.09 THB
    v_exists BOOLEAN;
BEGIN
    -- 1. Identify User (Assume the same user as the other transaction today)
    -- We find the user who did the 520.33 transaction today
    SELECT w.profile_id, w.id INTO v_user_id, v_wallet_id
    FROM transactions t
    JOIN wallets w ON t.wallet_id = w.id
    WHERE (t.created_at AT TIME ZONE 'Asia/Bangkok')::date = '2026-02-02'
      AND t.amount = 52033 -- The one we just fixed to be Gross
    LIMIT 1;

    IF v_user_id IS NULL THEN
        RAISE NOTICE 'Could not find user from existing transaction. Aborting manual reconcile.';
        RETURN;
    END IF;

    -- 2. Check if already exists (Idempotency)
    SELECT EXISTS(SELECT 1 FROM transactions WHERE reference_id = v_ref_id) INTO v_exists;
    
    IF v_exists THEN
        RAISE NOTICE 'Transaction % already exists. Skipping.', v_ref_id;
        RETURN;
    END IF;

    RAISE NOTICE 'Restoring missing transaction % for user %', v_ref_id, v_user_id;

    -- 3. Insert Missing Transaction
    -- NOTE: RPC process_inbound_transaction creates ledger & updates balance.
    -- We can call the fixed RPC directly to do everything properly!
    
    PERFORM process_inbound_transaction(
        p_user_id := v_user_id,
        p_amount_satang := v_charge_amount, -- Charge Amount (Gross) as per new Logic
        p_provider := 'omise',
        p_provider_txn_id := v_charge_id,
        p_reference_id := v_ref_id,
        p_description := 'TopUp: Wallet Top Up (Recovered)',
        p_metadata := jsonb_build_object(
            'wallet_amount_satang', v_wallet_amount,
            'charge_amount_satang', v_charge_amount,
            'manual_reconcile', true
        )
    );

END $$;
