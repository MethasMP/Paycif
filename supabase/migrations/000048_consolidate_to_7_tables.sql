-- 1. DROP LEGACY TABLES (Clean state)
DROP TABLE IF EXISTS public.wallets CASCADE;
DROP TABLE IF EXISTS public.ledger_entries CASCADE;
DROP TABLE IF EXISTS public.payout_intents CASCADE;
DROP TABLE IF EXISTS public.cache_saved_payment_methods CASCADE;
DROP TABLE IF EXISTS public.identity_verification CASCADE;
DROP TABLE IF EXISTS public.exchange_rates CASCADE;
DROP TABLE IF EXISTS public.fx_rate_history CASCADE;
DROP TABLE IF EXISTS public.security_events CASCADE;

-- 2. ENSURE ALL 7 CORE TABLES EXIST

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT,
    full_name TEXT,
    email TEXT UNIQUE,
    omise_customer_id TEXT,
    preferred_payment_method_id TEXT,
    preferred_payment_method_type TEXT,
    biometric_enabled BOOLEAN DEFAULT FALSE,
    has_pin BOOLEAN DEFAULT FALSE,
    kyc_status TEXT,
    kyc_provider_id TEXT,
    default_card_token TEXT,
    card_brand TEXT,
    last4 TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_device_bindings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    device_id TEXT,
    device_name TEXT,
    public_key TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now(),
    last_used_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_auth_secrets (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    pin_hash TEXT,
    failed_attempts INT DEFAULT 0,
    locked_until TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT now(),
    last_used_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    reference_id TEXT UNIQUE,
    idempotency_key TEXT,
    description TEXT,
    amount_thb BIGINT,
    amount_usd BIGINT,
    fx_rate NUMERIC,
    promptpay_id TEXT,
    merchant_name TEXT,
    sqril_tx_id TEXT,
    status TEXT DEFAULT 'PENDING',
    type TEXT,
    gateway_fee BIGINT,
    metadata JSONB DEFAULT '{}'::jsonb,
    provider_metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.transaction_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID REFERENCES public.transactions(id) ON DELETE CASCADE,
    event_type TEXT,
    payload JSONB,
    status TEXT DEFAULT 'PENDING',
    retry_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_type TEXT,
    payload JSONB,
    status TEXT DEFAULT 'PENDING',
    retry_count INT DEFAULT 0,
    max_retries INT DEFAULT 5,
    scheduled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action VARCHAR(100),
    resource_type VARCHAR(50),
    resource_id VARCHAR(100),
    metadata JSONB,
    request_id VARCHAR(100),
    ip_address VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. INDEXING (Supabase 2026 Best Practices)
CREATE INDEX IF NOT EXISTS idx_user_device_bindings_user_id ON public.user_device_bindings(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_profile_id ON public.transactions(profile_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_profile_created ON public.transactions(profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_pending ON public.transactions(id) WHERE status = 'PENDING';

-- 4. AUTOVACUUM TUNING (High-churn queue tables)
ALTER TABLE public.jobs SET (autovacuum_vacuum_scale_factor = 0.05);
ALTER TABLE public.transaction_outbox SET (autovacuum_vacuum_scale_factor = 0.05);

-- 5. ROW LEVEL SECURITY (RLS Optimization rule: wrap functions in SELECT for per-row caching)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_device_bindings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_auth_secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Optimize policies with (SELECT auth.uid()) wrapper
DROP POLICY IF EXISTS "Users view own profile" ON public.profiles;
CREATE POLICY "Users view own profile" ON public.profiles FOR SELECT USING ((SELECT auth.uid()) = id);

DROP POLICY IF EXISTS "Users update own profile" ON public.profiles;
CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE USING ((SELECT auth.uid()) = id);

DROP POLICY IF EXISTS "Users view own bindings" ON public.user_device_bindings;
CREATE POLICY "Users view own bindings" ON public.user_device_bindings FOR ALL USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users view own transactions" ON public.transactions;
CREATE POLICY "Users view own transactions" ON public.transactions FOR SELECT USING ((SELECT auth.uid()) = profile_id);

DROP POLICY IF EXISTS "Users view own audit logs" ON public.audit_logs;
CREATE POLICY "Users view own audit logs" ON public.audit_logs FOR SELECT USING ((SELECT auth.uid()) = user_id);

-- Security Definer Function for PIN Secret verification
CREATE OR REPLACE FUNCTION verify_user_auth_secret(p_user_id UUID, p_pin_hash TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
    v_stored_hash TEXT;
BEGIN
    SELECT pin_hash INTO v_stored_hash
    FROM public.user_auth_secrets
    WHERE user_id = p_user_id;

    RETURN v_stored_hash = p_pin_hash;
END;
$$;
