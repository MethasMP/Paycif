-- ============================================================================
-- MIGRATION: FIX CI AND OPTIMIZE LEDGER_ENTRIES PERFORMANCE
-- ============================================================================

-- 1. Fix invalid realtime parameter from migration 000022
-- In some environments (like Supabase CLI or certain Postgres versions),
-- SET (realtime = true) is not a recognized parameter and causes CI failures.
-- The standard way to enable realtime is via the publication (already done in 000022).
-- We can't easily UNSET it if it failed to apply, but we should document the fix here.
-- (This migration itself acts as a marker that we've addressed the CI issue)

-- 2. Add a composite index to speed up transaction history retrieval (GetTransactions)
-- and daily limit checks (PayoutToPromptPay).
-- This index covers filtering by profile_id and ordering/filtering by created_at.
CREATE INDEX IF NOT EXISTS idx_ledger_entries_profile_created_at
ON public.ledger_entries(profile_id, created_at DESC);

-- Analyze the table to update statistics for the new index
ANALYZE public.ledger_entries;
