-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table: profiles
CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username TEXT UNIQUE NOT NULL,
    full_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table: wallets
CREATE TABLE wallets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    currency TEXT NOT NULL, -- e.g., 'USD', 'EUR', 'BTC'
    balance BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT balance_non_negative CHECK (balance >= 0)
);

-- Index for wallet lookups
CREATE INDEX idx_wallets_profile_currency ON wallets(profile_id, currency);

-- Table: transactions
-- Represents a group of ledger entries making up a single financial event
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reference_id TEXT UNIQUE, -- External reference, unique for idempotency
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB
);

-- Index for transaction history (optional if reference_id is used for lookups often)
CREATE INDEX idx_transactions_reference_id ON transactions(reference_id);

-- Table: ledger_entries
-- The individual debit/credit lines
CREATE TABLE ledger_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE RESTRICT,
    amount BIGINT NOT NULL, -- Positive for credit (add), Negative for debit (subtract)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for transaction history
CREATE INDEX idx_ledger_entries_wallet ON ledger_entries(wallet_id);
CREATE INDEX idx_ledger_entries_transaction ON ledger_entries(transaction_id);

-- Enforce strictly non-zero amounts for ledger entries if desired (usually good practice)
ALTER TABLE ledger_entries ADD CONSTRAINT amount_not_zero CHECK (amount <> 0);

-- Table: transaction_outbox
-- Stores events for background processing
CREATE TABLE transaction_outbox (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING',
    retry_count INT DEFAULT 0,
    last_attempt_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE
);

-- Index for polling pending events (including backoff handling)
CREATE INDEX idx_outbox_status_retry ON transaction_outbox(status, last_attempt_at);

-- Type: kyc_status_enum
CREATE TYPE kyc_status_enum AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- Table: identity_verification
-- Stores KYC information linked to profiles
CREATE TABLE identity_verification (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    passport_number TEXT NOT NULL, -- Encrypted at application level before inserting
    full_name TEXT NOT NULL,
    nationality TEXT NOT NULL,
    kyc_status kyc_status_enum DEFAULT 'PENDING',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for verification lookups
CREATE INDEX idx_identity_verification_user ON identity_verification(user_id);

-- Table: exchange_rates
-- Stores the latest exchange rates (e.g. EUR -> THB)
CREATE TABLE exchange_rates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    from_currency TEXT NOT NULL,
    to_currency TEXT NOT NULL,
    mid_rate DECIMAL(20, 8) NOT NULL,
    provider_rate DECIMAL(20, 8) NOT NULL,
    spread DECIMAL(10, 8) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_currency_pair UNIQUE (from_currency, to_currency)
);

-- Table: fx_rate_history
-- Audit log of rate changes
CREATE TABLE fx_rate_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exchange_rate_id UUID REFERENCES exchange_rates(id),
    from_currency TEXT NOT NULL,
    to_currency TEXT NOT NULL,
    mid_rate DECIMAL(20, 8) NOT NULL,
    provider_rate DECIMAL(20, 8) NOT NULL,
    captured_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

