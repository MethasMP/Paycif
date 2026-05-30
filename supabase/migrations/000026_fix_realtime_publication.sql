-- ============================================================================
-- MIGRATION: ADD USER_DEVICE_BINDINGS TO REALTIME PUBLICATION
-- ============================================================================

-- 1. Add user_device_bindings to supabase_realtime publication
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' 
            AND schemaname = 'public' 
            AND tablename = 'user_device_bindings'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.user_device_bindings;
        END IF;
    ELSE
        CREATE PUBLICATION supabase_realtime FOR TABLE 
            public.transactions,
            public.user_device_bindings;
    END IF;
END
$$;

-- 2. Ensure Replica Identity is set to FULL for user_device_bindings
-- This is mandatory for realtime stream filters to work correctly in Flutter client
ALTER TABLE public.user_device_bindings REPLICA IDENTITY FULL;
