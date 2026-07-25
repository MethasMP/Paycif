-- Migration: Rename custodial "wallets" nomenclature to non-custodial "payment_accounts"
-- Aligning with Paysif's position as a Cross-Border Payment Orchestration Platform.

-- 1. Rename wallets table to payment_accounts
ALTER TABLE IF EXISTS public.wallets RENAME TO payment_accounts;

-- 2. Rename ledger_entries column wallet_id to account_id
ALTER TABLE IF EXISTS public.ledger_entries RENAME COLUMN wallet_id TO account_id;

-- 3. Rename indexes for clarity
ALTER INDEX IF EXISTS idx_wallets_profile_currency RENAME TO idx_payment_accounts_profile_currency;
ALTER INDEX IF EXISTS idx_ledger_entries_wallet RENAME TO idx_ledger_entries_account;

-- 4. Update table comment
COMMENT ON TABLE public.payment_accounts IS 'Non-custodial user payment orchestration accounts tracked for partner settlement.';
