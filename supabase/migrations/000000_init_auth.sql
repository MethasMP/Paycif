-- Pre-migration: Create dummy auth, realtime schemas, uid() function, and service_role/authenticated/anon roles for standard Postgres compatibility
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS realtime;

CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid AS $$
  SELECT null::uuid;
$$ LANGUAGE sql;

-- Create service_role, authenticated, and anon roles if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon;
    END IF;
END
$$;

-- Create dummy cache_saved_cards table for migration 27 compatibility
CREATE TABLE IF NOT EXISTS public.cache_saved_cards (
    user_id UUID PRIMARY KEY,
    cards_json JSONB,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
