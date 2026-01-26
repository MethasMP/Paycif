-- =============================================
-- 🧹 CLEANUP MIGRATION: Remove Legacy Debt
-- =============================================

-- 'pin_enabled' is redundant because we have 'has_pin'.
-- 'has_pin' = Fact (User has a PIN).
-- 'pin_enabled' = State (User disabled PIN?). But in finance app, PIN is Mandatory.

ALTER TABLE public.profiles 
DROP COLUMN IF EXISTS pin_enabled;

-- Comment for future maintainers
COMMENT ON COLUMN public.profiles.has_pin IS 'True if user has securely set a PIN. Serves as the single source of truth.';
