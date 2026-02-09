-- ============================================================================
-- ENABLE REALTIME FOR CORE TABLES
-- ============================================================================

-- 1. Enable Realtime for wallets
-- This allows the app to update the balance instantly when a top-up or payout occurs
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'wallets'
    ) THEN
        ALTER publication supabase_realtime ADD TABLE public.wallets;
    END IF;
END
$$;

-- 2. Enable Realtime for transactions
-- This allows the transaction history to refresh automatically
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'transactions'
    ) THEN
        ALTER publication supabase_realtime ADD TABLE public.transactions;
    END IF;
END
$$;

-- 3. Set Replica Identity to FULL for enriched payloads
-- (Optional, but recommended for more complex synchronization logic)
ALTER TABLE public.wallets REPLICA IDENTITY FULL;
ALTER TABLE public.transactions REPLICA IDENTITY FULL;
