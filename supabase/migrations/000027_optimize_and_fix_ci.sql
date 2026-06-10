-- ============================================================================
-- MIGRATION: OPTIMIZE LEDGER_ENTRIES PERFORMANCE & CI FIX
-- ============================================================================

-- 1. Add a composite index to speed up transaction history retrieval (GetTransactions)
-- and daily limit checks (PayoutToPromptPay).
-- This index covers filtering by profile_id and ordering/filtering by created_at.
CREATE INDEX IF NOT EXISTS idx_ledger_entries_profile_created_at
ON public.ledger_entries(profile_id, created_at DESC);

-- Analyze the table to update statistics for the new index
ANALYZE public.ledger_entries;

-- 2. Fix CI failure from migration 000022
-- SET (realtime = true) causes CI failures in some Postgres environments.
-- We ensure realtime is enabled for wallets and transactions by adding them
-- to the supabase_realtime publication if they aren't already.
-- (This is the standard and safe way to handle realtime in Supabase migrations).

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'wallets'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.wallets;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'transactions'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions;
    END IF;
END $$;
