-- Optimization for transaction history and limit checks
-- Performance win: Eliminates sequential scans on ledger_entries and transactions hot paths.

-- Index for transaction history and daily limit checks on ledger_entries
-- This allows fast retrieval of recent entries for a specific wallet.
CREATE INDEX IF NOT EXISTS idx_ledger_entries_wallet_id_created_at_desc
ON public.ledger_entries (wallet_id, created_at DESC);

-- Index for system-wide hourly limit checks on transactions
-- This allows fast retrieval of recent transactions for system breaker checks.
CREATE INDEX IF NOT EXISTS idx_transactions_created_at_desc
ON public.transactions (created_at DESC);
