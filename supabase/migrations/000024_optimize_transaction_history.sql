-- ============================================================================
-- OPTIMIZATION: Composite Index for Transaction History
-- ============================================================================

-- This index significantly improves the performance of transaction history lookups
-- which filter by wallet_id and sort by created_at DESC.
-- Target query:
-- SELECT l.id, l.wallet_id, l.amount, t.description, l.created_at
-- FROM ledger_entries l
-- JOIN transactions t ON l.transaction_id = t.id
-- WHERE l.wallet_id = $1
-- ORDER BY l.created_at DESC

CREATE INDEX IF NOT EXISTS idx_ledger_entries_wallet_created_at_desc
ON public.ledger_entries(wallet_id, created_at DESC);
