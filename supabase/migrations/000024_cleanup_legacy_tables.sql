-- ============================================================================
-- CLEANUP LEGACY UNUSED TABLES AND FUNCTIONS
-- Removes database drift from earlier development phases.
-- ============================================================================

-- Drop unused tables
DROP TABLE IF EXISTS public.daily_tabs CASCADE;
DROP TABLE IF EXISTS public.tab_items CASCADE;
DROP TABLE IF EXISTS public.risk_alerts CASCADE;

-- Drop unused functions
DROP FUNCTION IF EXISTS public.increment_user_tab(uuid, bigint, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.process_payout_with_tab(uuid, uuid, bigint, text) CASCADE;
