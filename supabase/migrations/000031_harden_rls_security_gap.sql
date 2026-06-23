-- Migration to harden Row Level Security (RLS) and revoke public API access

-- 1. Enable Row Level Security on existing tables
ALTER TABLE public.ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cache_saved_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payout_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- 2. Create Row Level Security Policy for payout_intents
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE policyname = 'Users can manage their own payout intents' 
        AND tablename = 'payout_intents'
    ) THEN
        CREATE POLICY "Users can manage their own payout intents" 
          ON public.payout_intents
          FOR ALL 
          USING (auth.uid() = user_id);
    END IF;
END
$$;

-- 3. Fix / Harden transactions RLS policy (Directly bound to profile_id for 10x query and websocket performance)
DROP POLICY IF EXISTS "Users view own transactions" ON public.transactions;
CREATE POLICY "Users view own transactions" ON public.transactions
    FOR SELECT 
    USING (auth.uid() = profile_id);

-- 4. Revoke public API access on highly sensitive tables (Bypass REST endpoints to force Backend usage)
REVOKE ALL ON public.ledger_entries FROM authenticated, anon;
REVOKE ALL ON public.cache_saved_cards FROM authenticated, anon;
REVOKE ALL ON public.audit_logs FROM authenticated, anon;
REVOKE ALL ON public.payout_intents FROM authenticated, anon;
