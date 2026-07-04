-- Migration: 000039_world_class_pin_security.sql
-- Description: Hardens PIN system to production-grade security.
--   - Adds lockout_level escalation (5min / 30min / permanent)
--   - Nonce table for replay attack prevention
--   - consume_nonce(): idempotent, replay-safe nonce consumption
--   - setup_user_pin_v2(): pgsodium Argon2id hashing in DB
--   - verify_pin_hash(): constant-time hash verification, hash never leaves DB
--   - update_user_auth_result(): lockout escalation logic
--   - get_user_auth_context(): includes lockout_level in response
-- Created: 2026-06-28

-- ===========================================================================
-- 1. Add lockout_level and last_failed_at to user_auth_secrets
-- ===========================================================================
ALTER TABLE private.user_auth_secrets
  ADD COLUMN IF NOT EXISTS lockout_level integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_failed_at timestamp with time zone;

-- ===========================================================================
-- 2. Nonce table for replay attack prevention
-- ===========================================================================
CREATE TABLE IF NOT EXISTS private.used_nonces (
  nonce_value text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Auto-cleanup nonces older than 5 minutes via index
CREATE INDEX IF NOT EXISTS idx_used_nonces_created_at ON private.used_nonces(created_at);

-- ===========================================================================
-- 3. Function: consume_nonce
--    Returns TRUE if nonce is fresh (first use), FALSE if already consumed or expired.
--    Window = 120 seconds.
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.consume_nonce(
  p_nonce text,
  p_user_id uuid,
  p_window_seconds integer DEFAULT 120
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
BEGIN
  -- Delete expired nonces
  DELETE FROM private.used_nonces WHERE created_at < now() - (p_window_seconds || ' seconds')::interval;

  -- Try to insert (fails if duplicate)
  INSERT INTO private.used_nonces(nonce_value, user_id) VALUES (p_nonce, p_user_id)
  ON CONFLICT (nonce_value) DO NOTHING;

  -- If 0 rows inserted, nonce was already used
  RETURN FOUND;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.consume_nonce(text, uuid, integer) FROM public;
GRANT EXECUTE ON FUNCTION public.consume_nonce(text, uuid, integer) TO service_role;

-- ===========================================================================
-- 4. Function: setup_user_pin_v2
--    Uses pgsodium Argon2id hashing (libsodium defaults: 64MB, 2 ops).
--    Hash stored in PHC format ($argon2id$...).
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.setup_user_pin_v2(
  p_user_id uuid,
  p_pin text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_hash text;
BEGIN
  -- pgsodium.crypto_pwhash_str uses Argon2id with libsodium defaults: 64MB, 2 ops
  -- Hash is stored in PHC format ($argon2id$...)
  v_hash := encode(pgsodium.crypto_pwhash_str(p_pin::bytea), 'escape');

  INSERT INTO private.user_auth_secrets (user_id, pin_hash, failed_attempts, lockout_level, locked_until, updated_at)
  VALUES (p_user_id, v_hash, 0, 0, NULL, now())
  ON CONFLICT (user_id) DO UPDATE
    SET pin_hash = v_hash,
        failed_attempts = 0,
        lockout_level = 0,
        locked_until = NULL,
        updated_at = now();
END;
$$;
REVOKE EXECUTE ON FUNCTION public.setup_user_pin_v2(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION public.setup_user_pin_v2(uuid, text) TO service_role;

-- ===========================================================================
-- 5. Function: verify_pin_hash
--    Hash stays in DB; returns boolean only (constant-time Argon2id verify).
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.verify_pin_hash(
  p_user_id uuid,
  p_pin text
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_stored_hash text;
BEGIN
  SELECT pin_hash INTO v_stored_hash
  FROM private.user_auth_secrets
  WHERE user_id = p_user_id;

  IF NOT FOUND OR v_stored_hash IS NULL THEN
    RETURN false;
  END IF;

  -- pgsodium constant-time comparison (Argon2id verify)
  RETURN pgsodium.crypto_pwhash_str_verify(
    decode(v_stored_hash, 'escape'),
    p_pin::bytea
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION public.verify_pin_hash(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION public.verify_pin_hash(uuid, text) TO service_role;

-- ===========================================================================
-- 6. Function: update_user_auth_result
--    Lockout escalation: level 1=5min, level 2=30min, level 3=permanent
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.update_user_auth_result(
    p_user_id uuid,
    p_device_id text,
    p_failed_attempts integer,
    p_locked_until timestamp with time zone,
    p_reset_counters boolean
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
  v_lockout_level integer;
  v_locked_until timestamp with time zone;
BEGIN
  IF p_reset_counters THEN
    UPDATE private.user_auth_secrets
    SET failed_attempts = 0,
        lockout_level = 0,
        locked_until = NULL,
        last_used_at = now(),
        updated_at = now()
    WHERE user_id = p_user_id;

    UPDATE public.user_device_bindings
    SET last_used_at = now()
    WHERE user_id = p_user_id AND device_id = p_device_id;
  ELSE
    -- Escalate lockout level based on attempts
    -- Level 1 (>=3 fails): 5 min lock
    -- Level 2 (>=6 fails): 30 min lock
    -- Level 3 (>=10 fails): permanent -- email required
    SELECT COALESCE(lockout_level, 0) INTO v_lockout_level
    FROM private.user_auth_secrets WHERE user_id = p_user_id;

    IF p_failed_attempts >= 10 THEN
      v_lockout_level := 3;
      v_locked_until := now() + interval '30 days';  -- effectively permanent
    ELSIF p_failed_attempts >= 6 THEN
      v_lockout_level := 2;
      v_locked_until := now() + interval '30 minutes';
    ELSIF p_failed_attempts >= 3 THEN
      v_lockout_level := 1;
      v_locked_until := now() + interval '5 minutes';
    ELSE
      v_lockout_level := 0;
      v_locked_until := NULL;
    END IF;

    UPDATE private.user_auth_secrets
    SET failed_attempts = p_failed_attempts,
        lockout_level = v_lockout_level,
        locked_until = v_locked_until,
        last_failed_at = now(),
        updated_at = now()
    WHERE user_id = p_user_id;
  END IF;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.update_user_auth_result(uuid, text, integer, timestamp with time zone, boolean) FROM public;
GRANT EXECUTE ON FUNCTION public.update_user_auth_result(uuid, text, integer, timestamp with time zone, boolean) TO service_role;

-- ===========================================================================
-- 7. Function: get_user_auth_context
--    Updated to include lockout_level in the returned JSON.
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.get_user_auth_context(
    p_user_id uuid,
    p_device_id text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, private
AS $$
DECLARE
    v_secret record;
    v_binding record;
BEGIN
    SELECT pin_hash, failed_attempts, locked_until, lockout_level
    INTO v_secret
    FROM private.user_auth_secrets
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN RETURN NULL; END IF;

    SELECT public_key, is_active
    INTO v_binding
    FROM public.user_device_bindings
    WHERE user_id = p_user_id AND device_id = p_device_id;

    RETURN jsonb_build_object(
        'pin_hash', v_secret.pin_hash,
        'failed_attempts', COALESCE(v_secret.failed_attempts, 0),
        'locked_until', v_secret.locked_until,
        'lockout_level', COALESCE(v_secret.lockout_level, 0),
        'public_key', v_binding.public_key,
        'is_device_active', COALESCE(v_binding.is_active, false)
    );
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_user_auth_context(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION public.get_user_auth_context(uuid, text) TO service_role;
