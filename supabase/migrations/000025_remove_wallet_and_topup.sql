-- ============================================================================
-- MIGRATION: REMOVE WALLETS & TOPUP SYSTEM FOR PURE PAY-PER-USE MODEL
-- ============================================================================

-- Drop dependent policies first
DROP POLICY IF EXISTS "Users can only see their own transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can view their own transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users view own transactions" ON public.transactions;

-- 1. Modify ledger_entries to refer to profiles directly instead of wallets
ALTER TABLE public.ledger_entries DROP CONSTRAINT IF EXISTS ledger_entries_wallet_id_fkey;
ALTER TABLE public.ledger_entries RENAME COLUMN wallet_id TO profile_id;
ALTER TABLE public.ledger_entries ADD CONSTRAINT ledger_entries_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 2. Modify transactions to drop wallet_id and add profile_id
ALTER TABLE public.transactions DROP COLUMN IF EXISTS wallet_id;
ALTER TABLE public.transactions ADD COLUMN profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Recreate policy for transactions based on profile_id
CREATE POLICY "Users can only see their own transactions" ON public.transactions
    FOR SELECT USING (auth.uid() = profile_id);

-- 3. Drop legacy/unused tables
DROP TABLE IF EXISTS public.wallets CASCADE;
DROP TABLE IF EXISTS private.daily_topup_tracking CASCADE;
DROP TABLE IF EXISTS private.topup_reservations CASCADE;

-- 4. Drop legacy functions related to daily limits, topup limits, and legacy transactions
DROP FUNCTION IF EXISTS public.check_and_update_daily_topup(uuid, bigint) CASCADE;
DROP FUNCTION IF EXISTS public.check_and_update_daily_topup(uuid, bigint, text) CASCADE;
DROP FUNCTION IF EXISTS public.rollback_daily_topup(uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.get_daily_topup_status(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.process_payout_request(uuid, uuid, bigint, text) CASCADE;
DROP FUNCTION IF EXISTS public.process_inbound_transaction(uuid, text, numeric, text, text) CASCADE;
