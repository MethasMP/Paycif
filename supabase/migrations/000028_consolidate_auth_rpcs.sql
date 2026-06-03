-- ============================================================================
-- Migration 000028: Consolidate Auth RPCs for High-Performance PIN Verification
-- ============================================================================

-- 1. Function: get_user_auth_context
-- Consolidates fetching user PIN secrets and device bindings in a single read.
CREATE OR REPLACE FUNCTION public.get_user_auth_context(
    p_user_id uuid,
    p_device_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
    v_secret record;
    v_binding record;
BEGIN
    -- Fetch PIN hash & lockout status from private schema
    SELECT pin_hash, failed_attempts, locked_until 
    INTO v_secret
    FROM private.user_auth_secrets
    WHERE user_id = p_user_id;
    
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;
    
    -- Fetch device public key & status
    SELECT public_key, is_active
    INTO v_binding
    FROM public.user_device_bindings
    WHERE user_id = p_user_id AND device_id = p_device_id;
    
    RETURN jsonb_build_object(
        'pin_hash', v_secret.pin_hash,
        'failed_attempts', COALESCE(v_secret.failed_attempts, 0),
        'locked_until', v_secret.locked_until,
        'public_key', v_binding.public_key,
        'is_device_active', COALESCE(v_binding.is_active, false)
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_user_auth_context(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION public.get_user_auth_context(uuid, text) TO service_role;


-- 2. Function: update_user_auth_result
-- Consolidates updating user PIN attempts and device last used status in a single transaction write.
CREATE OR REPLACE FUNCTION public.update_user_auth_result(
    p_user_id uuid,
    p_device_id text,
    p_failed_attempts integer,
    p_locked_until timestamp with time zone,
    p_reset_counters boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
    -- Update PIN auth status
    UPDATE private.user_auth_secrets
    SET 
        failed_attempts = CASE WHEN p_reset_counters THEN 0 ELSE p_failed_attempts END,
        locked_until = p_locked_until,
        updated_at = now(),
        last_used_at = CASE WHEN p_reset_counters THEN now() ELSE last_used_at END
    WHERE user_id = p_user_id;
    
    -- Update device last used if success
    IF p_reset_counters THEN
        UPDATE public.user_device_bindings
        SET last_used_at = now()
        WHERE user_id = p_user_id AND device_id = p_device_id;
    END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.update_user_auth_result(uuid, text, integer, timestamp with time zone, boolean) FROM public;
GRANT EXECUTE ON FUNCTION public.update_user_auth_result(uuid, text, integer, timestamp with time zone, boolean) TO service_role;
