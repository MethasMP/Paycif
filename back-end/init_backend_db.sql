-- Initialize missing backend-specific tables and schema updates

-- 1. Create exchange_rates table
CREATE TABLE IF NOT EXISTS public.exchange_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_currency TEXT NOT NULL,
    to_currency TEXT NOT NULL,
    mid_rate DECIMAL(20, 8) NOT NULL,
    provider_rate DECIMAL(20, 8) NOT NULL,
    spread DECIMAL(10, 8) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_currency_pair UNIQUE (from_currency, to_currency)
);

-- 2. Create fx_rate_history table
CREATE TABLE IF NOT EXISTS public.fx_rate_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exchange_rate_id UUID REFERENCES public.exchange_rates(id) ON DELETE SET NULL,
    from_currency TEXT NOT NULL,
    to_currency TEXT NOT NULL,
    mid_rate DECIMAL(20, 8) NOT NULL,
    provider_rate DECIMAL(20, 8) NOT NULL,
    captured_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Align local profiles schema with remote Supabase database
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS kyc_tier TEXT NOT NULL DEFAULT 'tier0'
  CHECK (kyc_tier IN ('tier0', 'tier1', 'tier2'));

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS kyc_status TEXT DEFAULT 'UNVERIFIED';

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS external_customer_id TEXT UNIQUE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS external_customer_type TEXT DEFAULT 'OMISE';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS openfort_wallet_address TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS coinflow_customer_id TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS payment_provider TEXT DEFAULT 'coinflow';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_lat DOUBLE PRECISION;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_lng DOUBLE PRECISION;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_txn_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS account_status TEXT DEFAULT 'ACTIVE';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS id_last_4 VARCHAR(4);

-- 4. Alchemy Pay KYC columns
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS ach_kyc_platform TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS ach_kyc_type TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS ach_user_no TEXT;

