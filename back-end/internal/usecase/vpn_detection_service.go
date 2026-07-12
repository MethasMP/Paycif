package usecase

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"github.com/sony/gobreaker"
)

// VPN/proxy detection via IPQualityScore's Proxy Detection API. This is a
// SECOND, independent check layered onto GeoBlockService's country lookup —
// a user physically outside Thailand can route through a Thailand-exit VPN
// and pass the country check undetected; this check exists to catch that.
// Both checks must pass for a money-movement request to proceed.
//
// Confirmed against IPQS's live docs (not assumed from memory): request is
// GET https://www.ipqualityscore.com/api/json/ip/{key}/{ip}, response has
// boolean `proxy`/`vpn`/`tor` fields and a `fraud_score` (0-100).
//
// Free tier is 1,000 lookups/month — far lower than ipapi.co/ipwho.is's
// 30k+, and will likely be the first geo dependency exhausted as volume
// grows. Quota exhaustion is logged distinctly (VPN_CHECK_QUOTA_EXCEEDED)
// from a genuine API outage (VPN_CHECK_FAILOPEN) so the two are
// distinguishable later without guessing — both still fail open the same
// way, but "we're out of quota" and "IPQS is down" call for different fixes.
var (
	ipqsAPIKey  = os.Getenv("IPQS_API_KEY")
	ipqsBaseURL = func() string {
		if v := os.Getenv("IPQS_BASE_URL"); v != "" {
			return v
		}
		return "https://www.ipqualityscore.com/api/json/ip"
	}()
	// Tunable without a redeploy: raise/lower how aggressively borderline
	// fraud scores get blocked.
	ipqsFraudScoreThreshold = func() int {
		if v := os.Getenv("IPQS_FRAUD_SCORE_THRESHOLD"); v != "" {
			if n, err := strconv.Atoi(v); err == nil {
				return n
			}
		}
		return 85
	}()
)

var consecutiveVPNCheckFailures int32

// quotaExceededError distinguishes "IPQS said no more lookups this month"
// from a generic network/API failure, purely for logging clarity.
type quotaExceededError struct {
	msg string
}

func (e quotaExceededError) Error() string {
	return "ipqs quota exceeded: " + e.msg
}

type ipqsResponse struct {
	Success    bool   `json:"success"`
	Message    string `json:"message"`
	Proxy      bool   `json:"proxy"`
	VPN        bool   `json:"vpn"`
	Tor        bool   `json:"tor"`
	FraudScore int    `json:"fraud_score"`
}

// VPNDetectionService flags whether a client IP is a VPN/proxy/Tor exit node
// or otherwise high-fraud-risk, via IPQualityScore.
type VPNDetectionService struct {
	cb *gobreaker.CircuitBreaker
}

// NewVPNDetectionService creates a new VPN/proxy detection service with a
// circuit breaker around the IPQS lookup, mirroring GeoBlockService.
func NewVPNDetectionService() *VPNDetectionService {
	settings := gobreaker.Settings{
		Name:        "IPQSProxyDetection",
		MaxRequests: 5,
		Interval:    10 * time.Second,
		Timeout:     30 * time.Second,
		ReadyToTrip: func(counts gobreaker.Counts) bool {
			failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
			return counts.Requests >= 3 && failureRatio >= 0.6
		},
	}

	return &VPNDetectionService{
		cb: gobreaker.NewCircuitBreaker(settings),
	}
}

// IsSuspicious reports whether ip looks like a VPN/proxy/Tor exit node or is
// otherwise high-fraud-risk (fraud_score above the configured threshold). On
// lookup failure it returns (false, err) — callers are responsible for
// failing open, matching GeoBlockService's contract.
func (s *VPNDetectionService) IsSuspicious(ctx context.Context, ip string) (bool, error) {
	result, err := s.cb.Execute(func() (interface{}, error) {
		if ipqsAPIKey == "" {
			return false, fmt.Errorf("IPQS_API_KEY not set")
		}

		url := fmt.Sprintf("%s/%s/%s", ipqsBaseURL, ipqsAPIKey, ip)
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
		if err != nil {
			return false, err
		}
		resp, err := geoBlockHTTPClient.Do(req)
		if err != nil {
			return false, err
		}
		defer resp.Body.Close()

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return false, err
		}
		if resp.StatusCode != http.StatusOK {
			return false, fmt.Errorf("ipqs returned status %d: %s", resp.StatusCode, string(body))
		}

		var parsed ipqsResponse
		if err := json.Unmarshal(body, &parsed); err != nil {
			return false, err
		}
		if !parsed.Success {
			msg := strings.ToLower(parsed.Message)
			if strings.Contains(msg, "exceed") || strings.Contains(msg, "limit") || strings.Contains(msg, "quota") {
				return false, quotaExceededError{msg: parsed.Message}
			}
			return false, fmt.Errorf("ipqs lookup unsuccessful: %s", parsed.Message)
		}

		suspicious := parsed.Proxy || parsed.VPN || parsed.Tor || parsed.FraudScore > ipqsFraudScoreThreshold
		return suspicious, nil
	})

	if err != nil {
		failures := atomic.AddInt32(&consecutiveVPNCheckFailures, 1)

		var quotaErr quotaExceededError
		if errors.As(err, &quotaErr) {
			log.Printf("VPN_CHECK_QUOTA_EXCEEDED: ip=%s: %s", TruncateIP(ip), quotaErr.msg)
		} else {
			log.Printf("VPN_CHECK_FAILOPEN: vpn/proxy lookup failed for ip=%s: %v", TruncateIP(ip), err)
		}

		if failures >= geoFailureAlertThreshold {
			log.Printf("ALERT: %d consecutive VPN/proxy lookup failures — IPQS may be down or quota exhausted, VPN detection is currently fail-open", failures)
			maybeSendFailoverAlert("VPN/proxy detection (IPQS)", failures)
		}

		return false, err
	}

	atomic.StoreInt32(&consecutiveVPNCheckFailures, 0)
	return result.(bool), nil
}
