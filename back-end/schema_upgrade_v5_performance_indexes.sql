-- Paysif High-Performance DB Upgrade (V5)
-- Optimized indexes for high throughput ledger queries, exchange rate lookups, and transaction outbox polling

-- 1. Compound index for ledger history lookup by account & date
CREATE INDEX IF NOT EXISTS idx_ledger_entries_account_created 
ON public.ledger_entries (account_id, created_at DESC);

-- 2. Index for FX exchange rates pair lookups
CREATE INDEX IF NOT EXISTS idx_exchange_rates_pair_lookup 
ON public.exchange_rates (from_currency, to_currency);

-- 3. Optimized index for Transaction Outbox polling under high concurrency
CREATE INDEX IF NOT EXISTS idx_outbox_status_created 
ON public.transaction_outbox (status, created_at ASC) 
WHERE status = 'PENDING';
