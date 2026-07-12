package usecase

import (
	"context"
	"database/sql"
	"log"
	"time"
)

// SecurityEventService persists security-incident events (as opposed to
// ordinary user/business activity, which goes through AuditService with
// IP-truncated, PDPA-minimized logging). A Cloudflare-bypass rejection is
// evidence of a deliberate attempt to route around a security control, not
// user-behavior data, so it's written with the full IP to its own
// service-role-only table (security_events) rather than being subject to the
// same truncation policy as country-block declines.
type SecurityEventService struct {
	DB *sql.DB
}

func NewSecurityEventService(db *sql.DB) *SecurityEventService {
	return &SecurityEventService{DB: db}
}

// LogCloudflareBypassRejection records a request whose Fly-Client-IP wasn't
// found in Cloudflare's published ranges — i.e. it reached the process via
// the public *.fly.dev origin instead of through Cloudflare's edge/WAF.
//
// Fire-and-forget: runs in its own goroutine with a short timeout so a slow
// or unavailable database never delays the 403 response already sent to the
// caller. A nil receiver (DB not wired up, e.g. in unit tests) is a no-op.
func (s *SecurityEventService) LogCloudflareBypassRejection(rawIP, path, method, userAgent, requestID string, matchedRange bool) {
	if s == nil || s.DB == nil {
		return
	}

	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		_, err := s.DB.ExecContext(ctx, `
			INSERT INTO security_events (event_type, raw_ip, matched_cloudflare_range, request_path, request_method, user_agent, request_id)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
		`, "cloudflare_bypass_rejected", rawIP, matchedRange, path, method, userAgent, requestID)

		if err != nil {
			// The truncated log.Printf line in CloudflareBypassMiddleware is
			// still the fallback record if this insert fails — don't let a
			// DB hiccup mean the rejection went completely unrecorded.
			log.Printf("security_event: failed to persist cloudflare_bypass_rejected: %v", err)
		}
	}()
}
