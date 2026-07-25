-- Migration 000046: Harden Security Definers
-- Hardens any legacy SECURITY DEFINER functions in public schema by setting an explicit search_path.
-- This prevents Search Path Hijacking / Privilege Escalation vulnerabilities.

ALTER FUNCTION public.process_inbound_transaction(uuid, bigint, text, text, text, text, jsonb) SET search_path = public;
