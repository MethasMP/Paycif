-- Trigger to ensuring wallet creation on profile creation
-- This assumes that 'profiles' table is populated when a user signs up.
-- If using Supabase Auth, you might need a trigger on auth.users instead, 
-- but since we have a profiles table, we'll attach it there for now, 
-- or ensure profiles is created from auth.users.

-- 1. Create the function
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.wallets (profile_id, currency, balance)
  VALUES (new.id, 'THB', 0); -- Default to THB
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON public.profiles;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
