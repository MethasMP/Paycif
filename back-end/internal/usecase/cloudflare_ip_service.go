package usecase

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/netip"
	"os"
	"strings"
	"sync/atomic"
	"time"

	"github.com/sony/gobreaker"
)

// Cloudflare publishes its edge IP ranges at these URLs (newline-separated
// CIDRs). CloudflareIPRangeService uses them to verify that a request's
// Fly-Client-IP (the real TCP peer, set unforgeably by Fly's edge proxy)
// actually belongs to Cloudflare — proving the request came through
// Cloudflare's WAF rather than hitting the public *.fly.dev URL directly.
var (
	cloudflareIPv4URL = func() string {
		if v := os.Getenv("CLOUDFLARE_IPS_V4_URL"); v != "" {
			return v
		}
		return "https://www.cloudflare.com/ips-v4"
	}()
	cloudflareIPv6URL = func() string {
		if v := os.Getenv("CLOUDFLARE_IPS_V6_URL"); v != "" {
			return v
		}
		return "https://www.cloudflare.com/ips-v6"
	}()
)

var cloudflareIPHTTPClient = &http.Client{
	Timeout: 5 * time.Second,
}

// SetCloudflareIPURLsForTest overrides the Cloudflare IP-range fetch URLs
// and returns the previous values, so cross-package tests (e.g. the
// cloudflare_bypass middleware tests) can point them at an httptest.Server.
// Not for production use.
func SetCloudflareIPURLsForTest(v4URL, v6URL string) (oldV4, oldV6 string) {
	oldV4, oldV6 = cloudflareIPv4URL, cloudflareIPv6URL
	cloudflareIPv4URL, cloudflareIPv6URL = v4URL, v6URL
	return oldV4, oldV6
}

const cloudflareIPRefreshInterval = 6 * time.Hour

var consecutiveCloudflareIPFailures int32

// CloudflareIPRangeService caches Cloudflare's published edge IP ranges and
// answers whether a given IP belongs to Cloudflare. The list is refreshed
// periodically in the background rather than fetched per-request.
type CloudflareIPRangeService struct {
	prefixes atomic.Pointer[[]netip.Prefix]
	cb       *gobreaker.CircuitBreaker
	stopCh   chan struct{}
}

// NewCloudflareIPRangeService creates a new service with a circuit breaker
// around the Cloudflare IP-range fetch, mirroring GeoBlockService.
func NewCloudflareIPRangeService() *CloudflareIPRangeService {
	settings := gobreaker.Settings{
		Name:        "CloudflareIPRangeFetch",
		MaxRequests: 5,
		Interval:    10 * time.Second,
		Timeout:     30 * time.Second,
		ReadyToTrip: func(counts gobreaker.Counts) bool {
			failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
			return counts.Requests >= 3 && failureRatio >= 0.6
		},
	}

	return &CloudflareIPRangeService{
		cb:     gobreaker.NewCircuitBreaker(settings),
		stopCh: make(chan struct{}),
	}
}

// Start performs one synchronous refresh (so callers can fail boot if there
// is no usable IP list at all) and then spawns a background goroutine that
// refreshes the list every cloudflareIPRefreshInterval.
func (s *CloudflareIPRangeService) Start(ctx context.Context) error {
	if err := s.Refresh(ctx); err != nil {
		return fmt.Errorf("initial Cloudflare IP range fetch failed: %w", err)
	}

	go func() {
		ticker := time.NewTicker(cloudflareIPRefreshInterval)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				if err := s.Refresh(context.Background()); err != nil {
					log.Printf("CLOUDFLARE_IP_STALE: refresh failed, continuing to serve last-known-good list: %v", err)
				}
			case <-s.stopCh:
				return
			}
		}
	}()

	return nil
}

// Stop halts the background refresh goroutine.
func (s *CloudflareIPRangeService) Stop() {
	close(s.stopCh)
}

// Contains reports whether ip falls within any of Cloudflare's published
// ranges. Returns false if ip is unparseable or no list has ever loaded.
func (s *CloudflareIPRangeService) Contains(ip string) bool {
	parsed, err := netip.ParseAddr(ip)
	if err != nil {
		return false
	}

	prefixes := s.prefixes.Load()
	if prefixes == nil {
		return false
	}

	for _, prefix := range *prefixes {
		if prefix.Contains(parsed) {
			return true
		}
	}
	return false
}

// Refresh fetches both the IPv4 and IPv6 Cloudflare range lists and, only if
// both succeed and parse to a non-empty combined list, atomically swaps the
// cached ranges. On any failure the previously cached list (if any) is left
// untouched — a transient outage on cloudflare.com should not zero out the
// list and fail-closed every request.
func (s *CloudflareIPRangeService) Refresh(ctx context.Context) error {
	result, err := s.cb.Execute(func() (interface{}, error) {
		v4, err := fetchCIDRList(ctx, cloudflareIPv4URL)
		if err != nil {
			return nil, fmt.Errorf("fetching ips-v4: %w", err)
		}
		v6, err := fetchCIDRList(ctx, cloudflareIPv6URL)
		if err != nil {
			return nil, fmt.Errorf("fetching ips-v6: %w", err)
		}

		combined := append(v4, v6...)
		if len(combined) == 0 {
			return nil, fmt.Errorf("parsed zero CIDRs from Cloudflare IP range lists")
		}
		return combined, nil
	})

	if err != nil {
		failures := atomic.AddInt32(&consecutiveCloudflareIPFailures, 1)
		if failures >= geoFailureAlertThreshold {
			log.Printf("ALERT: %d consecutive Cloudflare IP range refresh failures — bypass-detection may be serving a stale list", failures)
			maybeSendFailoverAlert("Cloudflare IP range refresh", failures)
		}
		return err
	}

	atomic.StoreInt32(&consecutiveCloudflareIPFailures, 0)
	prefixes := result.([]netip.Prefix)
	s.prefixes.Store(&prefixes)
	return nil
}

func fetchCIDRList(ctx context.Context, url string) ([]netip.Prefix, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	resp, err := cloudflareIPHTTPClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("unexpected status %d: %s", resp.StatusCode, string(body))
	}

	var prefixes []netip.Prefix
	scanner := bufio.NewScanner(resp.Body)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		prefix, err := netip.ParsePrefix(line)
		if err != nil {
			return nil, fmt.Errorf("invalid CIDR %q: %w", line, err)
		}
		prefixes = append(prefixes, prefix)
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}

	return prefixes, nil
}
