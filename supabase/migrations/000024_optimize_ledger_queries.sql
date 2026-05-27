-- ⚡ Bolt: Optimize ledger queries and transaction limit checks
-- Added composite index on ledger_entries(wallet_id, created_at DESC)
-- to speed up transaction history retrieval and daily limit fallback checks.

CREATE INDEX IF NOT EXISTS idx_ledger_entries_wallet_created_at
ON public.ledger_entries(wallet_id, created_at DESC);

-- Also optimize hourly system limit check on transactions table
CREATE INDEX IF NOT EXISTS idx_transactions_created_at
ON public.transactions(created_at DESC);
