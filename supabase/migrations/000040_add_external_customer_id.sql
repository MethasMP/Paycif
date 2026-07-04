ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS external_customer_id TEXT UNIQUE;
