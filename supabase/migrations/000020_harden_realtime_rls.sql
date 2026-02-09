-- ============================================================================
-- HARDEN REALTIME & CORE SECURITY
-- ============================================================================

-- 1. Enable RLS on core tables (missing in complete_schema)
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 2. Create Security Policies
-- Wallets: Users can only see their own wallets
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users view own wallets' AND tablename = 'wallets') THEN
        CREATE POLICY "Users view own wallets" ON public.wallets
            FOR SELECT USING (auth.uid() = profile_id);
    END IF;
END
$$;

-- Transactions: Users can only see transactions belonging to their wallet
-- We use a subquery to verify the wallet ownership.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users view own transactions' AND tablename = 'transactions') THEN
        CREATE POLICY "Users view own transactions" ON public.transactions
            FOR SELECT USING (
                EXISTS (
                    SELECT 1 FROM public.wallets 
                    WHERE wallets.id = transactions.wallet_id 
                    AND wallets.profile_id = auth.uid()
                )
            );
    END IF;
END
$$;

-- Profiles: Users can only see and update their own profile
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users manage own profile' AND tablename = 'profiles') THEN
        CREATE POLICY "Users manage own profile" ON public.profiles
            FOR ALL USING (auth.uid() = id);
    END IF;
END
$$;

-- 3. Optimization: Force Replica Identity to FULL for transactions
-- This ensures the stream payload contains all old/new data for reliable UI sync
ALTER TABLE public.transactions REPLICA IDENTITY FULL;

-- 4. Publication Fix: Ensure the authenticated role can access the publication
-- This is critical for Supabase Realtime to function with Auth
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;
