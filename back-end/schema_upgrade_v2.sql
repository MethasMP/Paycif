-- Upgrading ZapPay Schema to Production-Grade Financial System (V2)

-- ==========================================
-- Task 1: FX Rate Engine
-- ==========================================

-- Table: exchange_rates
-- Stores real-time rates. Only the latest rate per pair is needed here.
CREATE TABLE public.exchange_rates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    from_currency TEXT NOT NULL,
    to_currency TEXT NOT NULL,
    mid_rate NUMERIC(20, 10) NOT NULL, -- Market rate
    provider_rate NUMERIC(20, 10) NOT NULL, -- Rate given to users (after spread)
    spread NUMERIC(10, 5) NOT NULL DEFAULT 0, -- Our profit margin (e.g., 0.005 for 0.5%)
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_currency_pair UNIQUE (from_currency, to_currency)
);

-- Table: fx_rate_history
-- 10x analytics and historical gain/loss calculation
CREATE TABLE public.fx_rate_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exchange_rate_id UUID REFERENCES public.exchange_rates(id) ON DELETE SET NULL,
    from_currency TEXT NOT NULL,
    to_currency TEXT NOT NULL,
    mid_rate NUMERIC(20, 10) NOT NULL,
    provider_rate NUMERIC(20, 10) NOT NULL,
    captured_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for analytics queries
CREATE INDEX idx_fx_history_pair_time ON public.fx_rate_history(from_currency, to_currency, captured_at DESC);


-- ==========================================
-- Task 2: Advanced Ledger (Double-Entry)
-- ==========================================

-- Alter ledger_entries to add running balance and multi-currency tracking
ALTER TABLE public.ledger_entries
ADD COLUMN balance_after BIGINT, -- Snapshot of wallet balance after this entry
ADD COLUMN base_currency_amount BIGINT, -- Equivalent value in THB (System Base)
ADD COLUMN home_currency_amount BIGINT; -- Amount in Transaction's/User's Home Currency (e.g. EUR)

-- Update balance_after (This would typically need a migration script to backfill, 
-- but for schema definition we declare the column. 
-- In a real prod environment, you'd run a DO block to calculate this.)

-- ==========================================
-- Task 3: Settlement & Fee Management
-- ==========================================

-- Create settlement status enum
CREATE TYPE settlement_status_enum AS ENUM ('UNSETTLED', 'PENDING', 'SETTLED', 'FAILED', 'DISPUTED');

ALTER TABLE public.transactions
ADD COLUMN settlement_status settlement_status_enum DEFAULT 'UNSETTLED',
ADD COLUMN gateway_fee BIGINT DEFAULT 0, -- Cost of "Giant's shoulder"
ADD COLUMN provider_metadata JSONB DEFAULT '{}'::jsonb; -- Raw debugging 500 errors

-- Index for settlement reconciliation
CREATE INDEX idx_transactions_settlement ON public.transactions(settlement_status);


-- ==========================================
-- Task 4: Scaling to Bank (White-Label Readiness)
-- ==========================================

ALTER TABLE public.wallets
ADD COLUMN account_type TEXT NOT NULL DEFAULT 'VIRTUAL'; -- 'VIRTUAL', 'CUSTODIAL_BANK', 'MERCHANT'

-- Index for account type filtering
CREATE INDEX idx_wallets_account_type ON public.wallets(account_type);


-- ==========================================
-- Constraints & Security (FinTech Best Practices)
-- ==========================================

-- Row Level Security (RLS)
ALTER TABLE public.exchange_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fx_rate_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;

-- Policy: Exchange Rates are public read-only
CREATE POLICY "Public read exchange rates" ON public.exchange_rates FOR SELECT USING (true);

-- Policy: Wallets viewable by owner
CREATE POLICY "Users view own wallets" ON public.wallets
    FOR SELECT USING (auth.uid() = profile_id);

-- Policy: Ledger entries viewable by wallet owner (via join)
-- Note: Subqueries in RLS can be expensive, optimise carefully in prod
CREATE POLICY "Users view own ledger" ON public.ledger_entries
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.wallets 
            WHERE wallets.id = ledger_entries.wallet_id 
            AND wallets.profile_id = auth.uid()
        )
    );

-- Policy: Transactions viewable if user owns any involved wallet (simplified)
-- (Requires more complex logic if joining through ledger_entries, simplified here for schema)

-- Additional Check Constraints

-- Prevent negative gateway fees (unless it's a refund adjustment?) usually fees are >= 0
ALTER TABLE public.transactions ADD CONSTRAINT gateway_fee_non_negative CHECK (gateway_fee >= 0);

