-- Migration 000034: Harden transactions.profile_id NOT NULL

-- 1. Backfill Phase 1: From ledger_entries
UPDATE public.transactions t
SET profile_id = le.profile_id
FROM public.ledger_entries le
WHERE t.id = le.transaction_id
  AND t.profile_id IS NULL;

-- 2. Backfill Phase 2: From payout_intents
UPDATE public.transactions t
SET profile_id = pi.user_id
FROM public.payout_intents pi
WHERE t.reference_id = pi.sqril_tx_id
  AND t.profile_id IS NULL;

-- 3. Safety Check: Assert no NULLs remain before applying constraint
DO $$
DECLARE
  null_count INT;
BEGIN
  SELECT COUNT(*) INTO null_count FROM public.transactions WHERE profile_id IS NULL;
  IF null_count > 0 THEN
    RAISE EXCEPTION 'Cannot harden transactions.profile_id constraint: % orphan rows found with NULL profile_id', null_count;
  END IF;
END $$;

-- 4. Set NOT NULL constraint
ALTER TABLE public.transactions ALTER COLUMN profile_id SET NOT NULL;
