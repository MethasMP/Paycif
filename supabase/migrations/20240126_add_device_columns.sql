-- =============================================
-- 🛡️ WORLD-CLASS SECURITY MIGRATION (HARDENED)
-- =============================================

ALTER TABLE public.user_device_bindings 
-- 1. Identity & Integrity
ADD COLUMN IF NOT EXISTS device_name TEXT NOT NULL CHECK (length(device_name) > 0),
ADD COLUMN IF NOT EXISTS os_type TEXT NOT NULL CHECK (os_type IN ('ios', 'android', 'web')),
ADD COLUMN IF NOT EXISTS app_version TEXT, -- Nullable for now, but critical for future bindings

-- 2. Security Forensics
ADD COLUMN IF NOT EXISTS trust_score SMALLINT DEFAULT 100, -- 0-100 Risk Score
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb, -- Store screen_size, biometric_type, etc.

-- 3. Audit Trails
ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS revoked_reason TEXT;

-- 4. Constraint Hardening
-- Ensure active devices have a valid last_used_at
ALTER TABLE public.user_device_bindings 
ADD CONSTRAINT valid_activity 
CHECK (NOT (is_active = true AND last_used_at IS NULL));

-- Comments for Team Clarity
COMMENT ON COLUMN public.user_device_bindings.device_name IS 'Human readable model e.g. iPhone 15 Pro';
COMMENT ON COLUMN public.user_device_bindings.os_type IS 'Strict Enum: ios, android, web';
COMMENT ON COLUMN public.user_device_bindings.trust_score IS 'Risk score: <50 = suspicious, 0 = banned';
COMMENT ON COLUMN public.user_device_bindings.revoked_at IS 'Timestamp of revocation for fraud analysis';
