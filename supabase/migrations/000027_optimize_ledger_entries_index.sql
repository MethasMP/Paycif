-- ============================================================================
-- MIGRATION: OPTIMIZE LEDGER_ENTRIES PERFORMANCE
-- ============================================================================

-- Add a composite index to speed up transaction history retrieval (GetTransactions)
-- and daily limit checks (PayoutToPromptPay).
-- This index covers filtering by profile_id and ordering/filtering by created_at.
CREATE INDEX IF NOT EXISTS idx_ledger_entries_profile_created_at
ON public.ledger_entries(profile_id, created_at DESC);

-- Analyze the table to update statistics for the new index
ANALYZE public.ledger_entries;
