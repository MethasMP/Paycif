-- security_events: security-incident log, distinct from audit_logs.
--
-- audit_logs / application logs record ordinary user/business events and are
-- deliberately IP-truncated for PDPA data-minimization (see TruncateIP in
-- back-end/internal/usecase/geo_block_service.go) — that's correct for a
-- normal user action or a routine country-block decline.
--
-- A Cloudflare-bypass rejection is not that: it's evidence of a deliberate
-- attempt to route around a security control (hitting the public *.fly.dev
-- origin directly instead of going through Cloudflare/WAF). That is a
-- security-incident record, not user-behavior data, so it gets its own table
-- with the full (untruncated) IP and no default-imposed truncation policy.
-- Retention/legal-basis specifics should still be confirmed with the BOT/PDPA
-- consultation already underway; this migration only establishes the
-- separate category so evidence isn't lost while that's pending.
CREATE TABLE IF NOT EXISTS public.security_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(50) NOT NULL,
    raw_ip VARCHAR(50) NOT NULL,
    matched_cloudflare_range BOOLEAN NOT NULL,
    request_path VARCHAR(255),
    request_method VARCHAR(10),
    user_agent TEXT,
    request_id VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_security_events_type_created ON public.security_events(event_type, created_at);
CREATE INDEX IF NOT EXISTS idx_security_events_raw_ip ON public.security_events(raw_ip);

-- Same lockdown as audit_logs (see 000031_harden_rls_security_gap.sql):
-- service-role only, no policies granted to authenticated/anon. This table
-- holds raw IPs specifically so it needs to be at least as locked down as
-- audit_logs, not less.
ALTER TABLE public.security_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.security_events FROM authenticated, anon;
