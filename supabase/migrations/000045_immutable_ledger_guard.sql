-- Migration 000045: Immutable Ledger Guard
-- Ensures that no ledger_entries can be updated or deleted under any circumstance.
-- This enforces absolute mathematical immutability on the ledger at the database level.
-- Includes a secure role-based bypass to allow developers/migrations to run smoothly.

CREATE OR REPLACE FUNCTION public.block_ledger_modification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- 🔓 Developer-Friendly & Secure Bypass:
  -- Only allow modifications if the execution context is 'postgres' or 'supabase_admin' (used by migrations and CLI).
  -- Block all modifications for application-level roles ('authenticated', 'anon', 'service_role') to prevent SQL injection or API hacks.
  IF session_user IN ('postgres', 'supabase_admin') THEN
    RETURN OLD;
  END IF;

  RAISE EXCEPTION '🚨 CRITICAL SECURITY FAULT: Immutable ledger entries cannot be updated or deleted!';
END;
$$;

-- Create trigger to block UPDATE or DELETE operations on ledger_entries
DROP TRIGGER IF EXISTS lock_ledger_modification ON public.ledger_entries;
CREATE TRIGGER lock_ledger_modification
  BEFORE UPDATE OR DELETE ON public.ledger_entries
  FOR EACH ROW EXECUTE PROCEDURE public.block_ledger_modification();
