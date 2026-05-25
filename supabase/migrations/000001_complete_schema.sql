-- ============================================================================
-- COMPLETE DATABASE SCHEMA MIGRATION
-- Combines all previous migrations into single file for clean setup
-- ============================================================================

-- Using built-in gen_random_uuid() instead of uuid-ossp extension

-- ============================================================================
-- 1. CORE TABLES
-- ============================================================================

-- Table: profiles
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT UNIQUE NOT NULL,
    full_name TEXT,
    email TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    omise_customer_id TEXT UNIQUE,
    preferred_payment_method_id TEXT,
    preferred_payment_method_type TEXT,
    biometric_enabled BOOLEAN DEFAULT false,
    has_pin BOOLEAN DEFAULT false,
    kyc_status TEXT DEFAULT 'PENDING'
);

-- Table: wallets
CREATE TABLE IF NOT EXISTS public.wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    currency TEXT NOT NULL DEFAULT 'THB',
    balance BIGINT NOT NULL DEFAULT 0 CHECK (balance >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    account_type TEXT NOT NULL DEFAULT 'VIRTUAL',
    status TEXT DEFAULT 'active'
);

CREATE INDEX IF NOT EXISTS idx_wallets_profile ON wallets(profile_id);

-- Table: transactions
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_id TEXT UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB,
    status TEXT NOT NULL DEFAULT 'PENDING',
    gateway_fee BIGINT DEFAULT 0 CHECK (gateway_fee >= 0),
    provider_metadata JSONB DEFAULT '{}',
    wallet_id UUID REFERENCES public.wallets(id),
    type TEXT DEFAULT 'PAYOUT',
    amount BIGINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_transactions_reference_id ON transactions(reference_id);
CREATE INDEX IF NOT EXISTS idx_transactions_wallet ON transactions(wallet_id);

-- Table: ledger_entries
CREATE TABLE IF NOT EXISTS public.ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
    wallet_id UUID NOT NULL REFERENCES public.wallets(id),
    amount BIGINT NOT NULL CHECK (amount <> 0),
    type TEXT NOT NULL DEFAULT 'CREDIT' CHECK (type IN ('DEBIT', 'CREDIT')),
    currency VARCHAR DEFAULT 'THB',
    description TEXT,
    balance_after BIGINT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ledger_entries_wallet ON ledger_entries(wallet_id);
CREATE INDEX IF NOT EXISTS idx_ledger_entries_transaction ON ledger_entries(transaction_id);

-- ============================================================================
-- 2. PRIVATE SCHEMA (Security)
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS private;

-- Table: user_auth_secrets
CREATE TABLE IF NOT EXISTS private.user_auth_secrets (
  user_id uuid NOT NULL PRIMARY KEY,
  pin_hash text,
  failed_attempts integer DEFAULT 0,
  locked_until timestamp with time zone,
  updated_at timestamp with time zone DEFAULT now(),
  last_used_at timestamp with time zone DEFAULT now(),
  CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE
);

-- ============================================================================
-- 3. USER DEVICE BINDINGS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_device_bindings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  device_id text NOT NULL,
  public_key text NOT NULL,
  is_active boolean DEFAULT true,
  last_used_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  device_name text DEFAULT 'Unknown Device',
  os_type text DEFAULT 'web',
  app_version text,
  trust_score smallint DEFAULT 100,
  metadata jsonb DEFAULT '{}',
  revoked_at timestamp with time zone,
  revoked_reason text,
  CONSTRAINT unique_user_device UNIQUE (user_id, device_id)
);

-- Add constraints
ALTER TABLE public.user_device_bindings 
ADD CONSTRAINT check_device_name_length CHECK (length(device_name) > 0),
ADD CONSTRAINT check_os_type CHECK (lower(os_type) IN ('ios', 'android', 'web'));

-- Enable RLS
ALTER TABLE public.user_device_bindings ENABLE ROW LEVEL SECURITY;

-- Create policy
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE policyname = 'Users view own bindings' 
        AND tablename = 'user_device_bindings'
    ) THEN
        CREATE POLICY "Users view own bindings" ON public.user_device_bindings
            FOR SELECT USING (auth.uid() = user_id);
    END IF;
END
$$;

-- ============================================================================
-- 4. DAILY TOP-UP LIMITS
-- ============================================================================

CREATE TABLE IF NOT EXISTS private.daily_topup_tracking (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  topup_date date NOT NULL DEFAULT CURRENT_DATE,
  total_amount_satang bigint NOT NULL DEFAULT 0,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT unique_user_daily_topup UNIQUE (user_id, topup_date),
  CONSTRAINT non_negative_total CHECK (total_amount_satang >= 0)
);

CREATE INDEX IF NOT EXISTS idx_daily_topup_user_date ON private.daily_topup_tracking(user_id, topup_date);

-- Function: check_and_update_daily_topup
-- 🛡️ RACE CONDITION SAFE: Uses row-level locking (FOR UPDATE)
CREATE OR REPLACE FUNCTION private.check_and_update_daily_topup(
  p_user_id uuid,
  p_amount_satang bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_today date := CURRENT_DATE;
  v_current_total bigint;
  v_max_daily bigint := 300000; -- 3,000 THB in satang
  v_remaining bigint;
  v_result jsonb;
  v_record_id uuid;
BEGIN
  -- 🛡️ CRITICAL: Lock the row for this user+date to prevent race conditions
  -- This ensures only one transaction can check/update the limit at a time
  
  -- First, try to get existing record with exclusive lock
  SELECT id, total_amount_satang 
  INTO v_record_id, v_current_total
  FROM private.daily_topup_tracking
  WHERE user_id = p_user_id AND topup_date = v_today
  FOR UPDATE;  -- 🔒 Row-level lock acquired here
  
  -- If no record exists, create one with lock
  IF v_record_id IS NULL THEN
    INSERT INTO private.daily_topup_tracking (user_id, topup_date, total_amount_satang)
    VALUES (p_user_id, v_today, 0)
    RETURNING id, total_amount_satang INTO v_record_id, v_current_total;
    -- New row is automatically locked by the implicit transaction
  END IF;
  
  v_remaining := v_max_daily - v_current_total;
  
  IF p_amount_satang > v_remaining THEN
    v_result := jsonb_build_object(
      'success', false,
      'error', 'Daily top-up limit exceeded',
      'current_total', v_current_total,
      'requested_amount', p_amount_satang,
      'remaining_limit', v_remaining,
      'max_daily', v_max_daily
    );
    RETURN v_result;
  END IF;
  
  -- Update the locked row
  UPDATE private.daily_topup_tracking
  SET total_amount_satang = total_amount_satang + p_amount_satang,
      updated_at = now()
  WHERE id = v_record_id;
  
  v_result := jsonb_build_object(
    'success', true,
    'previous_total', v_current_total,
    'new_total', v_current_total + p_amount_satang,
    'remaining_limit', v_remaining - p_amount_satang,
    'max_daily', v_max_daily
  );
  
  RETURN v_result;
END;
$$;

-- Function: get_daily_topup_status
CREATE OR REPLACE FUNCTION private.get_daily_topup_status(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_today date := CURRENT_DATE;
  v_current_total bigint := 0;
  v_max_daily bigint := 300000;
  v_min_per_txn bigint := 50000;
  v_result jsonb;
BEGIN
  SELECT total_amount_satang INTO v_current_total
  FROM private.daily_topup_tracking
  WHERE user_id = p_user_id AND topup_date = v_today;
  
  IF v_current_total IS NULL THEN
    v_current_total := 0;
  END IF;
  
  v_result := jsonb_build_object(
    'current_total', v_current_total,
    'max_daily', v_max_daily,
    'remaining_limit', GREATEST(0, v_max_daily - v_current_total),
    'min_per_transaction', v_min_per_txn,
    'is_limit_reached', v_current_total >= v_max_daily
  );
  
  RETURN v_result;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION private.check_and_update_daily_topup TO service_role;
GRANT EXECUTE ON FUNCTION private.get_daily_topup_status TO service_role;

-- ============================================================================
-- 5. AUTH RPC FUNCTIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_auth_secret(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
    secret_record record;
BEGIN
    SELECT pin_hash, failed_attempts, locked_until 
    INTO secret_record
    FROM private.user_auth_secrets
    WHERE user_id = p_user_id;
    
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;
    
    RETURN jsonb_build_object(
        'pin_hash', secret_record.pin_hash,
        'failed_attempts', COALESCE(secret_record.failed_attempts, 0),
        'locked_until', secret_record.locked_until
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.update_user_auth_status(
    p_user_id uuid, 
    p_failed_attempts integer, 
    p_locked_until timestamp with time zone,
    p_reset_counters boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
    UPDATE private.user_auth_secrets
    SET 
        failed_attempts = CASE WHEN p_reset_counters THEN 0 ELSE p_failed_attempts END,
        locked_until = p_locked_until,
        updated_at = now(),
        last_used_at = CASE WHEN p_reset_counters THEN now() ELSE last_used_at END
    WHERE user_id = p_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.setup_user_pin(
    p_user_id uuid, 
    p_pin_hash text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
    UPDATE public.profiles 
    SET has_pin = true, updated_at = now() 
    WHERE id = p_user_id;

    INSERT INTO private.user_auth_secrets (user_id, pin_hash, failed_attempts, locked_until, updated_at)
    VALUES (p_user_id, p_pin_hash, 0, NULL, now())
    ON CONFLICT (user_id) DO UPDATE 
    SET 
        pin_hash = EXCLUDED.pin_hash,
        failed_attempts = 0,
        locked_until = NULL,
        updated_at = now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_auth_secret(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.update_user_auth_status(uuid, integer, timestamptz, boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.setup_user_pin(uuid, text) TO service_role;

-- ============================================================================
-- 6. AUDIT LOGS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  action character varying NOT NULL,
  resource_type character varying NOT NULL,
  resource_id character varying,
  metadata jsonb,
  request_id character varying,
  ip_address character varying,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT audit_logs_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);

-- ============================================================================
-- 7. TRANSACTION OUTBOX
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.transaction_outbox (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL REFERENCES public.transactions(id),
  event_type text NOT NULL,
  payload jsonb NOT NULL,
  status text NOT NULL DEFAULT 'PENDING',
  retry_count integer DEFAULT 0,
  last_attempt_at timestamp with time zone,
  error_message text,
  created_at timestamp with time zone DEFAULT now(),
  processed_at timestamp with time zone,
  CONSTRAINT transaction_outbox_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_outbox_status_retry ON transaction_outbox(status, last_attempt_at);

-- ============================================================================
-- 8. COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON COLUMN public.user_device_bindings.device_name IS 'Human readable model e.g. iPhone 15 Pro';
COMMENT ON COLUMN public.user_device_bindings.os_type IS 'Strict Enum: ios, android, web';
COMMENT ON COLUMN public.user_device_bindings.trust_score IS 'Risk score: <50 = suspicious, 0 = banned';
COMMENT ON COLUMN public.user_device_bindings.revoked_at IS 'Timestamp of revocation for fraud analysis';
COMMENT ON COLUMN public.profiles.has_pin IS 'True if user has securely set a PIN. Serves as the single source of truth.';
COMMENT ON TABLE private.daily_topup_tracking IS 'Tracks daily top-up amounts per user for limit enforcement';
