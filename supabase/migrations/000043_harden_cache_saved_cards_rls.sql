-- Enable Row Level Security for cache_saved_cards table
ALTER TABLE public.cache_saved_cards ENABLE ROW LEVEL SECURITY;

-- Revoke all direct permissions from anon role to ensure no anonymous operations
REVOKE ALL ON public.cache_saved_cards FROM anon;

-- Ensure authenticated role has necessary table permissions (will be restricted by the RLS policy)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cache_saved_cards TO authenticated;

-- Create policy to restrict access only to the user who owns the record
CREATE POLICY "Users can manage their own cached cards"
ON public.cache_saved_cards
FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
