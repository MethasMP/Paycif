-- ============================================================================
-- FIX DATA & RECOVER MISSING TXN (ROBUST VERSION)
-- ============================================================================

DO $$
DECLARE
    v_user_id UUID;
    v_wallet_id UUID;
BEGIN
    -- 1. Identify User: Find ANY user who had a success TOPUP on 2026-02-02
    -- This handles the case where amount might still be Net (50001) or Gross (52033)
    SELECT w.profile_id, w.id INTO v_user_id, v_wallet_id
    FROM transactions t
    JOIN wallets w ON t.wallet_id = w.id
    WHERE t.type = 'TOPUP' AND t.status = 'SUCCESS'
    AND (t.created_at AT TIME ZONE 'Asia/Bangkok')::date = '2026-02-02'
    LIMIT 1;

    IF v_user_id IS NOT NULL THEN
        RAISE NOTICE 'Found active user: %', v_user_id;

        -- 2. Force Update existing txns to GROSS if they have metadata
        -- This repeats the previous logic just in case it missed
        UPDATE transactions
        SET amount = (provider_metadata->>'charge_amount_satang')::bigint
        WHERE wallet_id = v_wallet_id
          AND type = 'TOPUP'
          AND status = 'SUCCESS'
          AND provider_metadata ? 'charge_amount_satang'
          AND amount != (provider_metadata->>'charge_amount_satang')::bigint;

        -- 3. Recover the missing 100 THB transaction
        IF NOT EXISTS (SELECT 1 FROM transactions WHERE reference_id = '1769965857202') THEN
             RAISE NOTICE 'Restoring 100 THB transaction...';
             PERFORM process_inbound_transaction(
                p_user_id := v_user_id,
                p_amount_satang := 10000, -- 100.00 THB Gross
                p_provider := 'omise',
                p_provider_txn_id := 'chrg_test_66kmdq346ijf0mxgpza',
                p_reference_id := '1769965857202',
                p_description := 'TopUp: Wallet Top Up (Ref: 1769965857202)',
                p_metadata := jsonb_build_object(
                    'wallet_amount_satang', 9609,
                    'charge_amount_satang', 10000,
                    'manual_reconcile', true
                )
            );
        ELSE
             RAISE NOTICE 'Transaction 100 THB already exists.';
        END IF;

    ELSE
        RAISE NOTICE ' Still no user found for today 2026-02-02?! Checking timezone...';
    END IF;

    -- 4. Truncate tracking to force correct limit calc from transactions
    TRUNCATE TABLE private.daily_topup_tracking;
    
END $$;
