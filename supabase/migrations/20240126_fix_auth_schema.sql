-- =============================================
-- 🔒 AUTH SECURITY FIX: RPC & Schema Hardening
-- =============================================

-- 1. Ensure 'last_used_at' exists (Audit Trail)
ALTER TABLE private.user_auth_secrets 
ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMP WITH TIME ZONE DEFAULT now();

-- 2. Create RPC for Fetching Secret (Security Definer = Run as Owner)
-- This allows the Edge Function (Service Role) to read the private schema
-- strictly through this controlled interface, without exposing the schema via REST.
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

-- 3. Create RPC for Updating Status (Lockout & timestamp)
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

-- 4. Create RPC for Initializing/Updating PIN (Atomic)
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
    -- Update Profiles to signal PIN is set
    UPDATE public.profiles 
    SET has_pin = true, updated_at = now() 
    WHERE id = p_user_id;

    -- Upsert the secret in private schema
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

-- 5. Grant Permissions
GRANT EXECUTE ON FUNCTION public.get_user_auth_secret(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.update_user_auth_status(uuid, integer, timestamptz, boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.setup_user_pin(uuid, text) TO service_role;

