-- Migration 000044: Rename cache_saved_cards to cache_saved_payment_methods to support MoonPay ApplePay/GooglePay/etc.
-- And rename columns to generic naming convention.

-- 1. Rename table
ALTER TABLE IF EXISTS public.cache_saved_cards RENAME TO cache_saved_payment_methods;

-- 2. Rename columns for generic payment methods
ALTER TABLE public.cache_saved_payment_methods RENAME COLUMN cards_json TO payment_methods_json;

-- 3. Adjust RLS policies on the renamed table
-- The old policy will be renamed by PostgreSQL automatically, but let's drop it and rebuild it
-- to ensure clean names and definitions.
DROP POLICY IF EXISTS "Users can manage their own cached cards" ON public.cache_saved_payment_methods;

ALTER TABLE public.cache_saved_payment_methods ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.cache_saved_payment_methods FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cache_saved_payment_methods TO authenticated;

CREATE POLICY "Users can manage their own cached payment methods"
ON public.cache_saved_payment_methods
FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
