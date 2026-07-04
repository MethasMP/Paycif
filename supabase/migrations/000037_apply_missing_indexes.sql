-- Migration 000037: Add missing indexes (without CONCURRENTLY to prevent transaction errors)

-- 1. Balance queries index
CREATE INDEX IF NOT EXISTS idx_ledger_entries_profile_id 
  ON public.ledger_entries (profile_id);

-- 2. Idempotency check index
CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_reference_id 
  ON public.transactions (reference_id) WHERE reference_id IS NOT NULL;

-- 3. Outbox worker composite index
CREATE INDEX IF NOT EXISTS idx_outbox_status_attempt 
  ON public.transaction_outbox (status, last_attempt_at) 
  WHERE status IN ('PENDING', 'RETRY_PENDING');
