package usecase

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/netip"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/sony/gobreaker"
)

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

var consecutiveGeoFailures int32

const geoFailureAlertThreshold = 3

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
		return "alerts@resend.dev"
	}()
	resendBaseURL = func() string {
		if v := os.Getenv("RESEND_BASE_URL"); v != "" {
			return v
		}
		return "https://api.resend.com"
	}()
)

var lastAlertUnix int64

const geoAlertCooldown = 15 * time.Minute

// Local CIDR Bounding Database for Thailand (L1.5 Geofence Filter)
var (
	thCIDRBlocks       []netip.Prefix
	thCIDRBlocksLoaded int32
	thCIDRLoadMutex    sync.Mutex
)

// LoadTHCIDRBlocks loads the Thailand IP range CIDR subnets from local storage or downloads them.
func LoadTHCIDRBlocks() {
	if atomic.LoadInt32(&thCIDRBlocksLoaded) == 1 {
		return
	}
	thCIDRLoadMutex.Lock()
	defer thCIDRLoadMutex.Unlock()
	if thCIDRBlocksLoaded == 1 {
		return
	}

	// Always ensure that we mark it as loaded (success or failure) to prevent repeating load attempts.
	defer atomic.StoreInt32(&thCIDRBlocksLoaded, 1)

	filePath := "data/th_cidrs.txt"
	data, err := os.ReadFile(filePath)
	if err != nil {
		log.Println("⚠️ Local th_cidrs.txt not found. Fetching from public repository...")
		resp, dErr := http.Get("https://raw.githubusercontent.com/herrbischoff/country-ip-blocks/master/ipv4/th.cidr")
		if dErr == nil && resp.StatusCode == http.StatusOK {
			data, err = io.ReadAll(resp.Body)
			resp.Body.Close()
			if err == nil {
				_ = os.MkdirAll("data", 0755)
				_ = os.WriteFile(filePath, data, 0644)
			}
		}
	}

	if err != nil {
		log.Printf("⚠️ Failed to load or download th_cidrs.txt: %v. Local country lookup fallback is disabled.", err)
		return
	}

	lines := strings.Split(string(data), "\n")
	var blocks []netip.Prefix
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		prefix, parseErr := netip.ParsePrefix(line)
		if parseErr == nil {
			blocks = append(blocks, prefix)
		}
	}

	thCIDRBlocks = blocks
	log.Printf("✅ Loaded %d Thailand IP subnets into memory.", len(thCIDRBlocks))
}

// IsInThailandCIDR checks if client IP falls under Thailand network ranges.
func IsInThailandCIDR(ipStr string) bool {
	LoadTHCIDRBlocks()
	parsed, err := netip.ParseAddr(ipStr)
	if err != nil {
		return false
	}
	for _, subnet := range thCIDRBlocks {
		if subnet.Contains(parsed) {
			return true
		}
	}
	return false
}

// Two-Tier Cache for Geoblock
type geoCacheEntry struct {
	value      string
	expiration time.Time
}

var (
	geoL1Cache      = make(map[string]geoCacheEntry)
	geoL1CacheMutex sync.RWMutex
)

func getGeoL1(ip string) (string, bool) {
	geoL1CacheMutex.RLock()
	defer geoL1CacheMutex.RUnlock()
	entry, found := geoL1Cache[ip]
	if !found || time.Now().After(entry.expiration) {
		return "", false
	}
	return entry.value, true
}

func setGeoL1(ip string, country string, ttl time.Duration) {
	geoL1CacheMutex.Lock()
	defer geoL1CacheMutex.Unlock()
	geoL1Cache[ip] = geoCacheEntry{
		value:      country,
		expiration: time.Now().Add(ttl),
	}
}

func ClearGeoL1Cache() {
	geoL1CacheMutex.Lock()
	defer geoL1CacheMutex.Unlock()
	geoL1Cache = make(map[string]geoCacheEntry)
}

// IsAllowed reports whether country is allowed (strictly "TH").
func (s *GeoBlockService) IsAllowed(country string) bool {
	return strings.ToUpper(country) == "TH"
}

// IsInThailandGPS checks bounds
func (s *GeoBlockService) IsInThailandGPS(lat, lng float64) bool {
	return lat >= 5.6 && lat <= 20.5 && lng >= 97.3 && lng <= 105.6
}

// GeoBlockService resolves client IP to country.
type GeoBlockService struct {
	cb *gobreaker.CircuitBreaker
}

// NewGeoBlockService creates a new geo-block service with a circuit breaker.
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

func IsLocalIP(ip string) bool {
	if ip == "" {
		return true
	}
	parsed, err := netip.ParseAddr(ip)
	if err != nil {
		return false
	}
	return parsed.IsLoopback()
}

func TruncateIP(ip string) string {
	parsed, err := netip.ParseAddr(ip)
	if err != nil {
		return "invalid"
	}
	if parsed.Is4() {
		prefix := netip.PrefixFrom(parsed, 24)
		return prefix.Masked().Addr().String()
	}
	if parsed.Is6() {
		prefix := netip.PrefixFrom(parsed, 48)
		return prefix.Masked().Addr().String()
	}
	return "invalid"
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

// ResolveCountry looks up the country using a multi-tiered cache hierarchy and local database fallback.
func (s *GeoBlockService) ResolveCountry(ctx context.Context, ip string) (string, error) {
	if IsLocalIP(ip) {
		return "TH", nil
	}

	// 1. L1 In-Memory Cache check
	if val, found := getGeoL1(ip); found {
		return val, nil
	}

	// 2. L2 Redis Cache check
	redisKey := fmt.Sprintf("geo_country:%s", ip)
	if val, found := CacheGet(ctx, redisKey); found {
		setGeoL1(ip, val, 1*time.Hour)
		return val, nil
	}

	// 3. Local CIDR check (L1.5 filter)
	if IsInThailandCIDR(ip) {
		setGeoL1(ip, "TH", 1*time.Hour)
		CacheSet(ctx, redisKey, "TH", 24*time.Hour)
		return "TH", nil
	}

	// 4. API check with circuit breaker
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
		log.Printf("GEO_FAILCLOSED: geo lookup failed for ip=%s: %v", TruncateIP(ip), err)
		if failures >= geoFailureAlertThreshold {
			log.Printf("ALERT: %d consecutive geo-IP lookup failures — both providers may be down, geo-fencing is currently fail-closed", failures)
			maybeSendFailoverAlert("Country geo-fencing (ipapi.co/ipwho.is)", failures)
		}
		return "", err
	}

	atomic.StoreInt32(&consecutiveGeoFailures, 0)
	country := result.(string)

	// Save to caches
	setGeoL1(ip, country, 1*time.Hour)
	CacheSet(ctx, redisKey, country, 24*time.Hour)

	return country, nil
}

func maybeSendFailoverAlert(reason string, failures int32) {
	now := time.Now().Unix()
	last := atomic.LoadInt64(&lastAlertUnix)
	if last != 0 && time.Since(time.Unix(last, 0)) < geoAlertCooldown {
		return
	}
	if !atomic.CompareAndSwapInt64(&lastAlertUnix, last, now) {
		return
	}
	go sendFailoverAlertEmail(reason, failures)
}

func sendFailoverAlertEmail(reason string, failures int32) {
	if resendAPIKey == "" {
		log.Printf("geo alert: RESEND_API_KEY not set — %d consecutive failures on %q went unemailed", failures, reason)
		return
	}

	payload, err := json.Marshal(map[string]interface{}{
		"from":    alertFromEmail,
		"to":      []string{alertToEmail},
		"subject": fmt.Sprintf("Paycif ALERT: %s is down", reason),
		"text": fmt.Sprintf(
			"%s has failed %d times in a row.\n\n"+
				"This check is FAIL-CLOSED and will block non-TH requests.",
			reason, failures,
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

	log.Printf("geo alert: email sent to %s (%q, %d consecutive failures)", alertToEmail, reason, failures)
}
