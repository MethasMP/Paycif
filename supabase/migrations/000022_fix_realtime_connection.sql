-- 1. Optimized RLS for Transactions (Direct profile_id link for 10x Performance)
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS profile_id UUID REFERENCES public.profiles(id);

-- Backfill profile_id from wallets
UPDATE public.transactions t
SET profile_id = w.profile_id
FROM public.wallets w
WHERE t.wallet_id = w.id
AND t.profile_id IS NULL;

-- 2. Clean & Simple Policies for Realtime Filters
DROP POLICY IF EXISTS "Users view own transactions" ON public.transactions;
CREATE POLICY "Users view own transactions" ON public.transactions
    FOR SELECT USING (auth.uid() = profile_id);

DROP POLICY IF EXISTS "Users view own wallets" ON public.wallets;
CREATE POLICY "Users view own wallets" ON public.wallets
    FOR SELECT USING (auth.uid() = profile_id);

-- 3. Reset Realtime Infrastructure
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.wallets, 
    public.transactions;

-- Ensure ownership is correct for the publication engine
ALTER PUBLICATION supabase_realtime OWNER TO postgres;

-- 4. Set Replica Identity to FULL (MANDATORY for .stream() eq filters)
ALTER TABLE public.wallets REPLICA IDENTITY FULL;
ALTER TABLE public.transactions REPLICA IDENTITY FULL;

-- 5. Permission Overhaul
GRANT USAGE ON SCHEMA public TO authenticated, anon;
GRANT USAGE ON SCHEMA realtime TO authenticated, anon;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated, anon;

-- 6. Table-level Realtime Flags
ALTER TABLE public.wallets SET (realtime = true);
ALTER TABLE public.transactions SET (realtime = true);
