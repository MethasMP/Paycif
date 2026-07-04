-- Upgrading Paysif Schema: Indexing SQRIL transaction IDs for high performance (V4)

-- 1. Create functional index on transactions.provider_metadata->>'external_id'
CREATE INDEX IF NOT EXISTS idx_transactions_sqril_external_id 
ON public.transactions ((provider_metadata->>'external_id'));
