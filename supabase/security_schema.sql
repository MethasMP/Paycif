-- ==========================================
-- SECURITY SCHEMA SETUP
-- ==========================================

-- 1. Create the private schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS private;

-- 2. Table: private.user_auth_secrets
-- Stores hashed PINs and lockout state.
CREATE TABLE IF NOT EXISTS private.user_auth_secrets (
  user_id uuid NOT NULL,
  pin_hash text,
  failed_attempts integer DEFAULT 0,
  locked_until timestamp with time zone,
  updated_at timestamp with time zone DEFAULT now(),
  last_used_at timestamp with time zone,
  CONSTRAINT user_auth_secrets_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_auth_secrets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE
);

-- 3. Table: public.user_device_bindings
-- Stores public keys for device-hardened security.
CREATE TABLE IF NOT EXISTS public.user_device_bindings (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  device_id text NOT NULL,
  public_key text NOT NULL,
  is_active boolean DEFAULT true,
  last_used_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT unique_user_device UNIQUE (user_id, device_id)
);

-- 4. Update public.profiles
-- Add flags for security status and KYC.
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS has_pin BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS kyc_status TEXT DEFAULT 'PENDING';

-- 5. Enable RLS on public tables
ALTER TABLE public.user_device_bindings ENABLE ROW LEVEL SECURITY;

-- Note: user_device_bindings is managed via Edge Functions with Service Role, 
-- but users should be able to see their own bindings.
CREATE POLICY "Users view own bindings" ON public.user_device_bindings
    FOR SELECT USING (auth.uid() = user_id);
