-- Migration 000035: Remove Omise artifacts, add ACH on-ramp preferences
--
-- Omise is no longer used. Payment method credential storage is delegated to
-- AlchemyPay (ACH). Paycif stores only non-sensitive on-ramp preferences
-- (last-used fiat/crypto/network) to pre-fill the ACH widget on next visit.

-- 1. Drop Omise-specific columns from profiles
ALTER TABLE public.profiles
  DROP COLUMN IF EXISTS omise_customer_id,
  DROP COLUMN IF EXISTS preferred_payment_method_id,
  DROP COLUMN IF EXISTS preferred_payment_method_type;

-- 2. Add ACH on-ramp preferences (non-sensitive, user-owned)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS ach_user_token        TEXT,
  ADD COLUMN IF NOT EXISTS ach_token_expires_at  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_used_fiat         TEXT DEFAULT 'USD',
  ADD COLUMN IF NOT EXISTS last_used_crypto       TEXT DEFAULT 'USDC',
  ADD COLUMN IF NOT EXISTS last_used_network      TEXT DEFAULT 'BASE';

-- 3. Drop cache_saved_cards table (Omise card vault cache)
DROP TABLE IF EXISTS public.cache_saved_cards CASCADE;

-- 4. RLS: ensure ach preferences columns are owner-only
-- (profiles table already has RLS; the new columns inherit the existing policy)
-- Re-confirm the core policy exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'profiles' AND policyname = 'Users can view own profile'
  ) THEN
    CREATE POLICY "Users can view own profile"
      ON public.profiles FOR SELECT
      USING (auth.uid() = id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'profiles' AND policyname = 'Users can update own profile'
  ) THEN
    CREATE POLICY "Users can update own profile"
      ON public.profiles FOR UPDATE
      USING (auth.uid() = id);
  END IF;
END $$;
