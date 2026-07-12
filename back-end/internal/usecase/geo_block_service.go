package usecase

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"sync/atomic"
	"time"

	"github.com/sony/gobreaker"
)

// Geo-IP providers. Both are free, keyless tiers — fine for pre-launch
// volume, but move to a paid tier (or a self-hosted MaxMind DB) before this
// becomes a bottleneck. ipwho.is is tried only if ipapi.co fails, so a
// single-provider blip doesn't trip the circuit breaker.
var (
	ipapiBaseURL = func() string {
		if v := os.Getenv("IPAPI_BASE_URL"); v != "" {
			return v
		}
		return "https://ipapi.co"
	}()
	ipwhoisBaseURL = func() string {
		if v := os.Getenv("IPWHOIS_BASE_URL"); v != "" {
			return v
		}
		return "https://ipwho.is"
	}()
)

var geoBlockHTTPClient = &http.Client{
	Timeout: 5 * time.Second,
}

// consecutiveGeoFailures counts back-to-back total lookup failures (both
// providers down) across requests, so a sustained outage gets a loud ALERT
// log line instead of silently fading into per-request warnings.
var consecutiveGeoFailures int32

const geoFailureAlertThreshold = 3

// Failover alerting: log lines alone aren't a real safety net for a
// solo-founder setup with no monitoring dashboard, so once the failure
// threshold is hit we also push an email via Resend (HTTP API, no SMTP/2FA
// setup needed, free tier is plenty for this volume). lastAlertUnix +
// geoAlertCooldown stop a sustained outage from flooding the inbox — the
// first breach fires immediately, then alerts are suppressed for the
// cooldown window even if failures keep happening.
var (
	resendAPIKey = os.Getenv("RESEND_API_KEY")
	alertToEmail = func() string {
		if v := os.Getenv("GEO_ALERT_EMAIL_TO"); v != "" {
			return v
		}
		return "hello@paysif.io"
	}()
	alertFromEmail = func() string {
		if v := os.Getenv("GEO_ALERT_EMAIL_FROM"); v != "" {
			return v
		}
		// Resend's shared sandbox sender — works with no domain verification.
		// Verify a real sending domain in the Resend dashboard if this ever
		// lands in spam; fine as a starting point at zero setup cost.
		return "alerts@resend.dev"
	}()
	resendBaseURL = func() string {
		if v := os.Getenv("RESEND_BASE_URL"); v != "" {
			return v
		}
		return "https://api.resend.com"
	}()
)

var lastAlertUnix int64 // unix seconds of last sent alert; 0 = never sent

const geoAlertCooldown = 15 * time.Minute

// blockedCountries is the set of ISO 3166-1 alpha-2 codes MoonPay's
// regulatory-exposure requirement covers: US, UK, and the EU-27.
var blockedCountries = map[string]bool{
	"US": true, "GB": true,
	"AT": true, "BE": true, "BG": true, "HR": true, "CY": true, "CZ": true,
	"DK": true, "EE": true, "FI": true, "FR": true, "DE": true, "GR": true,
	"HU": true, "IE": true, "IT": true, "LV": true, "LT": true, "LU": true,
	"MT": true, "NL": true, "PL": true, "PT": true, "RO": true, "SK": true,
	"SI": true, "ES": true, "SE": true,
}

// GeoBlockService resolves a client IP to a country and decides whether the
// request must be blocked for regulatory geo-fencing (US/UK/EU).
type GeoBlockService struct {
	cb *gobreaker.CircuitBreaker
}

// NewGeoBlockService creates a new geo-block service with a circuit breaker
// around the external IP geolocation lookups, mirroring SanctionsService.
func NewGeoBlockService() *GeoBlockService {
	settings := gobreaker.Settings{
		Name:        "GeoIPLookup",
		MaxRequests: 5,
		Interval:    10 * time.Second,
		Timeout:     30 * time.Second,
		ReadyToTrip: func(counts gobreaker.Counts) bool {
			failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
			return counts.Requests >= 3 && failureRatio >= 0.6
		},
	}

	return &GeoBlockService{
		cb: gobreaker.NewCircuitBreaker(settings),
	}
}

// IsLocalIP reports whether ip is a loopback/dev address that should skip
// geo-fencing entirely (matches the convention already used in
// PaymentHandler.HandleCheckRegion).
func IsLocalIP(ip string) bool {
	return ip == "" || ip == "::1" || ip == "127.0.0.1"
}

// TruncateIP zeroes the last IPv4 octet (or the last 80 bits of an IPv6
// address) so logs retain enough precision for country-level audit
// correlation without persisting a full client IP long-term.
func TruncateIP(ip string) string {
	parsed := net.ParseIP(ip)
	if parsed == nil {
		return "invalid"
	}
	if v4 := parsed.To4(); v4 != nil {
		return fmt.Sprintf("%d.%d.%d.0", v4[0], v4[1], v4[2])
	}
	v6 := parsed.To16()
	if v6 == nil {
		return "invalid"
	}
	masked := net.CIDRMask(48, 128)
	return parsed.Mask(masked).String()
}

func fetchCountryFromIPAPI(ctx context.Context, ip string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, fmt.Sprintf("%s/%s/country/", ipapiBaseURL, ip), nil)
	if err != nil {
		return "", err
	}
	resp, err := geoBlockHTTPClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("ipapi.co returned status %d: %s", resp.StatusCode, string(body))
	}

	country := strings.ToUpper(strings.TrimSpace(string(body)))
	if len(country) != 2 {
		return "", fmt.Errorf("ipapi.co returned unexpected body: %s", string(body))
	}
	return country, nil
}

func fetchCountryFromIPWhois(ctx context.Context, ip string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, fmt.Sprintf("%s/%s", ipwhoisBaseURL, ip), nil)
	if err != nil {
		return "", err
	}
	resp, err := geoBlockHTTPClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var parsed struct {
		Success     bool   `json:"success"`
		CountryCode string `json:"country_code"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return "", err
	}
	if !parsed.Success || len(parsed.CountryCode) != 2 {
		return "", fmt.Errorf("ipwho.is lookup unsuccessful for ip")
	}
	return strings.ToUpper(parsed.CountryCode), nil
}

// ResolveCountry looks up the ISO country code for ip, trying ipapi.co first
// and falling back to ipwho.is within the same circuit-breaker call.
func (s *GeoBlockService) ResolveCountry(ctx context.Context, ip string) (string, error) {
	result, err := s.cb.Execute(func() (interface{}, error) {
		country, primaryErr := fetchCountryFromIPAPI(ctx, ip)
		if primaryErr == nil {
			return country, nil
		}

		country, fallbackErr := fetchCountryFromIPWhois(ctx, ip)
		if fallbackErr == nil {
			return country, nil
		}

		return "", fmt.Errorf("both geo providers failed: primary=%v fallback=%v", primaryErr, fallbackErr)
	})

	if err != nil {
		failures := atomic.AddInt32(&consecutiveGeoFailures, 1)
		log.Printf("GEO_FAILOPEN: geo lookup failed for ip=%s: %v", TruncateIP(ip), err)
		if failures >= geoFailureAlertThreshold {
			log.Printf("ALERT: %d consecutive geo-IP lookup failures — both providers may be down, geo-fencing is currently fail-open for all requests", failures)
			maybeSendFailoverAlert("Country geo-fencing (ipapi.co/ipwho.is)", failures)
		}
		return "", err
	}

	atomic.StoreInt32(&consecutiveGeoFailures, 0)
	return result.(string), nil
}

// IsBlocked reports whether country is in the blocked set (US/UK/EU-27).
func (s *GeoBlockService) IsBlocked(country string) bool {
	return blockedCountries[strings.ToUpper(country)]
}

// maybeSendFailoverAlert fires an async email alert once the failure
// threshold is hit, unless one already fired within geoAlertCooldown. The
// CompareAndSwap ensures that under concurrent requests only one goroutine
// claims the alert slot — the rest see the swap fail and skip silently.
//
// Shared across both geo dependencies (country lookup and VPN/proxy
// detection) via a single global cooldown/timestamp — if either external
// service is flapping you get one email, not two independent alert streams,
// and the reason string tells you which one tripped it.
func maybeSendFailoverAlert(reason string, failures int32) {
	now := time.Now().Unix()
	last := atomic.LoadInt64(&lastAlertUnix)
	if last != 0 && time.Since(time.Unix(last, 0)) < geoAlertCooldown {
		return
	}
	if !atomic.CompareAndSwapInt64(&lastAlertUnix, last, now) {
		return
	}
	// Never block the request that triggered this — the email send has its
	// own timeout and happens entirely off the request path.
	go sendFailoverAlertEmail(reason, failures)
}

// sendFailoverAlertEmail pushes a single alert email via Resend's HTTP API.
// This is the one real safety net for a solo-founder setup with no
// monitoring dashboard: if a geo dependency is down, the corresponding check
// is silently fail-open, and this is what surfaces that.
func sendFailoverAlertEmail(reason string, failures int32) {
	if resendAPIKey == "" {
		log.Printf("geo alert: RESEND_API_KEY not set — %d consecutive failures on %q went unemailed, log lines are the only record", failures, reason)
		return
	}

	payload, err := json.Marshal(map[string]interface{}{
		"from":    alertFromEmail,
		"to":      []string{alertToEmail},
		"subject": fmt.Sprintf("Paycif ALERT: %s is fail-open", reason),
		"text": fmt.Sprintf(
			"%s has failed %d times in a row.\n\n"+
				"This check is currently FAIL-OPEN: it is NOT blocking requests right now.\n\n"+
				"Further alerts are suppressed for %s even if failures continue, to avoid flooding this inbox.",
			reason, failures, geoAlertCooldown,
		),
	})
	if err != nil {
		log.Printf("geo alert: failed to build email payload: %v", err)
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, resendBaseURL+"/emails", bytes.NewReader(payload))
	if err != nil {
		log.Printf("geo alert: failed to build request: %v", err)
		return
	}
	req.Header.Set("Authorization", "Bearer "+resendAPIKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := geoBlockHTTPClient.Do(req)
	if err != nil {
		log.Printf("geo alert: failed to send via Resend: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		log.Printf("geo alert: Resend returned status %d: %s", resp.StatusCode, string(body))
		return
	}

	log.Printf("geo alert: failover email sent to %s (%q, %d consecutive failures)", alertToEmail, reason, failures)
}
