-- Migration 000041: Grant explicit SELECT and UPDATE privileges on public.profiles to authenticated role
-- This resolves the "permission denied for table profiles" error when syncing FCM tokens and notification preferences.

GRANT SELECT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
