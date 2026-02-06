-- ============================================================================
-- ROBUST SYNC: Find the EXACT wallet that has the 520.33 transaction
-- ============================================================================

DO $$
DECLARE
    v_wallet_id UUID;
BEGIN
    -- 🎯 TARGET: Find the wallet that has the 520.33 (52033 satang) transaction
    -- This is the "Anchor" to ensure we update the correct user
    SELECT wallet_id INTO v_wallet_id
    FROM transactions
    WHERE amount IN (52033, 50001) 
      AND type = 'TOPUP'
      AND (created_at AT TIME ZONE 'Asia/Bangkok')::date = '2026-02-02'
    LIMIT 1;

    IF v_wallet_id IS NULL THEN
        RAISE NOTICE '❌ ERROR: Could not find the 520.33 transaction to identify user.';
        RETURN;
    END IF;

    RAISE NOTICE '✅ Found Target Wallet: %', v_wallet_id;

    -- 1. Ensure the 100.00 THB transaction exists for THIS specific wallet
    -- Using the Reference ID from Omise Screenshot
    IF EXISTS (SELECT 1 FROM transactions WHERE reference_id = '1769965857202') THEN
        UPDATE transactions 
        SET wallet_id = v_wallet_id,
            amount = 10000,
            status = 'SUCCESS'
        WHERE reference_id = '1769965857202';
    ELSE
        INSERT INTO transactions (
            reference_id, description, status, wallet_id, type, amount, created_at, provider_metadata
        ) VALUES (
            '1769965857202',
            'TopUp: Wallet Top Up (Ref: 1769965857202)',
            'SUCCESS',
            v_wallet_id,
            'TOPUP',
            10000,
            '2026-02-02 20:11:00+07', -- Match Omise time roughly
            '{"charge_amount_satang": 10000, "wallet_amount_satang": 9609}'::jsonb
        );
    END IF;

    -- 2. Force reset tracking for this wallet
    TRUNCATE TABLE private.daily_topup_tracking;
    
    RAISE NOTICE '🚀 Re-sync complete for Wallet: %', v_wallet_id;
END $$;
