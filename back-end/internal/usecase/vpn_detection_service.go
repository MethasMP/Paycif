package usecase

import (
	"container/list"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/sony/gobreaker"
)

var (
	proxycheckAPIKey  = os.Getenv("PROXYCHECK_API_KEY")
	proxycheckBaseURL = func() string {
		if v := os.Getenv("PROXYCHECK_BASE_URL"); v != "" {
			return v
		}
		return "https://proxycheck.io/v2"
	}()
)

var consecutiveVPNCheckFailures int32

type quotaExceededError struct {
	msg string
}

func (e quotaExceededError) Error() string {
	return "proxycheck quota exceeded: " + e.msg
}

// Two-Tier Bounded LRU Cache for VPN Detection
type lruCacheEntry struct {
	key        string
	suspicious bool
	expiration time.Time
}

type boundedLRUCache struct {
	capacity  int
	items     map[string]*list.Element
	evictList *list.List
	mu        sync.RWMutex
}

func newBoundedLRUCache(capacity int) *boundedLRUCache {
	return &boundedLRUCache{
		capacity:  capacity,
		items:     make(map[string]*list.Element),
		evictList: list.New(),
	}
}

func (c *boundedLRUCache) Get(key string) (bool, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if elem, found := c.items[key]; found {
		entry := elem.Value.(*lruCacheEntry)
		if time.Now().After(entry.expiration) {
			c.removeElement(elem)
			return false, false
		}
		c.evictList.MoveToFront(elem)
		return entry.suspicious, true
	}
	return false, false
}

func (c *boundedLRUCache) Put(key string, suspicious bool, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if elem, found := c.items[key]; found {
		c.evictList.MoveToFront(elem)
		entry := elem.Value.(*lruCacheEntry)
		entry.suspicious = suspicious
		entry.expiration = time.Now().Add(ttl)
		return
	}

	entry := &lruCacheEntry{
		key:        key,
		suspicious: suspicious,
		expiration: time.Now().Add(ttl),
	}
	elem := c.evictList.PushFront(entry)
	c.items[key] = elem

	if c.evictList.Len() > c.capacity {
		c.removeOldest()
	}
}

func (c *boundedLRUCache) removeOldest() {
	elem := c.evictList.Back()
	if elem != nil {
		c.removeElement(elem)
	}
}

func (c *boundedLRUCache) removeElement(elem *list.Element) {
	c.evictList.Remove(elem)
	entry := elem.Value.(*lruCacheEntry)
	delete(c.items, entry.key)
}

func (c *boundedLRUCache) Purge() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.items = make(map[string]*list.Element)
	c.evictList.Init()
}

var vpnL1LRUCache = newBoundedLRUCache(10000)

func getVPNL1(ip string) (bool, bool) {
	return vpnL1LRUCache.Get(ip)
}

func setVPNL1(ip string, suspicious bool, ttl time.Duration) {
	vpnL1LRUCache.Put(ip, suspicious, ttl)
}

func ClearVPNL1Cache() {
	vpnL1LRUCache.Purge()
}

// VPNCheckResult contains detailed decision output for middleware evaluation.
type VPNCheckResult struct {
	Suspicious   bool
	IsDegraded   bool // set true when external lookup failed & system operates in degraded state
	ProviderUsed string
}

// VPNDetectionService flags whether a client IP is a VPN/proxy/Tor exit node.
type VPNDetectionService struct {
	cb      *gobreaker.CircuitBreaker
	ipqsSvc *IPQSService
}

// NewVPNDetectionService creates a new VPN/proxy detection service.
func NewVPNDetectionService() *VPNDetectionService {
	settings := gobreaker.Settings{
		Name:        "ProxycheckDetection",
		MaxRequests: 5,
		Interval:    10 * time.Second,
		Timeout:     30 * time.Second,
		ReadyToTrip: func(counts gobreaker.Counts) bool {
			failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
			return counts.Requests >= 3 && failureRatio >= 0.6
		},
	}

	return &VPNDetectionService{
		cb:      gobreaker.NewCircuitBreaker(settings),
		ipqsSvc: NewIPQSService(),
	}
}

// IsSuspicious reports whether ip looks like a VPN/proxy/Tor exit node (without extra headers).
func (s *VPNDetectionService) IsSuspicious(ctx context.Context, ip string) (bool, error) {
	return s.IsSuspiciousWithHeaders(ctx, ip, "", "")
}

// IsSuspiciousWithHeaders reports whether ip looks like a VPN/proxy/Tor exit node, passing optional headers to providers like IPQS.
func (s *VPNDetectionService) IsSuspiciousWithHeaders(ctx context.Context, ip string, userAgent string, userLanguage string) (bool, error) {
	if IsLocalIP(ip) {
		return false, nil
	}

	// 1. L1 Cache Check
	if val, found := getVPNL1(ip); found {
		return val, nil
	}

	// 2. L2 Redis Cache Check
	redisKey := "vpn_check:" + ip
	if cachedVal, found := CacheGet(ctx, redisKey); found {
		isSuspicious := cachedVal == "yes"
		// Default TTL for cached hit
		setVPNL1(ip, isSuspicious, 1*time.Hour)
		return isSuspicious, nil
	}

	strategy := os.Getenv("VPN_PROVIDER_STRATEGY")
	if strategy == "" {
		strategy = "fallback"
	}

	switch strategy {
	case "ipqualityscore":
		suspicious, _, err := s.ipqsSvc.IsSuspicious(ctx, ip, userAgent, userLanguage)
		if err != nil {
			log.Printf("VPN_CHECK_FAILCLOSED: IPQS lookup failed for ip=%s: %v", TruncateIP(ip), err)
			return false, err
		}
		s.cacheResult(ctx, ip, suspicious, 24*time.Hour)
		return suspicious, nil

	case "dual":
		// Query Proxycheck first, then IPQS if available. Return true if either flags suspicious.
		pSuspicious, pErr := s.checkProxycheck(ctx, ip)
		ipqsSuspicious, _, ipqsErr := s.ipqsSvc.IsSuspicious(ctx, ip, userAgent, userLanguage)

		if pErr != nil && ipqsErr != nil {
			return false, fmt.Errorf("dual check failed: proxycheck err: %v, ipqs err: %v", pErr, ipqsErr)
		}

		suspicious := (pErr == nil && pSuspicious) || (ipqsErr == nil && ipqsSuspicious)
		s.cacheResult(ctx, ip, suspicious, 24*time.Hour)
		return suspicious, nil

	case "fallback":
		fallthrough
	default:
		// Attempt primary provider (Proxycheck if configured, or IPQS if Proxycheck key missing)
		var primaryErr error
		if proxycheckAPIKey != "" {
			suspicious, err := s.checkProxycheck(ctx, ip)
			if err == nil {
				return suspicious, nil
			}
			primaryErr = err
			log.Printf("VPN_CHECK_PRIMARY_FAILED: Proxycheck error for ip=%s (%v), attempting IPQS fallback", TruncateIP(ip), err)
		}

		// Fallback to IPQS
		if ipqsAPIKey != "" {
			suspicious, _, err := s.ipqsSvc.IsSuspicious(ctx, ip, userAgent, userLanguage)
			if err == nil {
				s.cacheResult(ctx, ip, suspicious, 24*time.Hour)
				return suspicious, nil
			}
			log.Printf("VPN_CHECK_FALLBACK_FAILED: IPQS lookup failed for ip=%s: %v", TruncateIP(ip), err)
			return false, err
		}

		if primaryErr != nil {
			return false, primaryErr
		}
		return false, fmt.Errorf("no VPN detection API keys configured (PROXYCHECK_API_KEY / IPQUALITYSCORE_API_KEY)")
	}
}

func (s *VPNDetectionService) checkProxycheck(ctx context.Context, ip string) (bool, error) {
	result, err := s.cb.Execute(func() (interface{}, error) {
		if proxycheckAPIKey == "" {
			return false, fmt.Errorf("PROXYCHECK_API_KEY not set")
		}

		url := fmt.Sprintf("%s/%s?key=%s&vpn=1&asn=1", proxycheckBaseURL, ip, proxycheckAPIKey)
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
			return false, fmt.Errorf("proxycheck returned status %d: %s", resp.StatusCode, string(body))
		}

		var parsed map[string]json.RawMessage
		if err := json.Unmarshal(body, &parsed); err != nil {
			return false, err
		}

		var status string
		if statusRaw, ok := parsed["status"]; ok {
			_ = json.Unmarshal(statusRaw, &status)
		}

		if status != "ok" {
			var msg string
			if msgRaw, ok := parsed["message"]; ok {
				_ = json.Unmarshal(msgRaw, &msg)
			}
			msgLower := strings.ToLower(msg)
			if strings.Contains(msgLower, "limit") || strings.Contains(msgLower, "quota") || strings.Contains(msgLower, "denied") {
				return false, quotaExceededError{msg: msg}
			}
			return false, fmt.Errorf("proxycheck lookup unsuccessful: %s", msg)
		}

		ipRaw, ok := parsed[ip]
		if !ok {
			return false, fmt.Errorf("ip %s not found in proxycheck response", ip)
		}

		var ipData struct {
			Proxy   string `json:"proxy"`
			Type    string `json:"type"`
			ASN     string `json:"asn"`
			Isocode string `json:"isocode"`
		}
		if err := json.Unmarshal(ipRaw, &ipData); err != nil {
			return false, err
		}

		isSuspicious := strings.ToLower(ipData.Proxy) == "yes"

		ttl := 24 * time.Hour
		if isSuspicious {
			ttl = 3 * time.Hour

			asn := strings.ToUpper(ipData.ASN)
			if ipData.Isocode == "TH" && (strings.Contains(asn, "AS131273") || strings.Contains(asn, "AS17552") || strings.Contains(asn, "AS45430") || strings.Contains(asn, "AS52030")) {
				ttl = 30 * time.Minute
			}
		}

		s.cacheResult(ctx, ip, isSuspicious, ttl)

		return isSuspicious, nil
	})

	if err != nil {
		failures := atomic.AddInt32(&consecutiveVPNCheckFailures, 1)

		var quotaErr quotaExceededError
		if errors.As(err, &quotaErr) {
			log.Printf("VPN_CHECK_QUOTA_EXCEEDED: ip=%s: %s", TruncateIP(ip), quotaErr.msg)
		} else {
			log.Printf("VPN_CHECK_FAILCLOSED: vpn/proxy lookup failed for ip=%s: %v", TruncateIP(ip), err)
		}

		if failures >= geoFailureAlertThreshold {
			log.Printf("ALERT: %d consecutive VPN/proxy lookup failures — Proxycheck may be down or quota exhausted", failures)
			maybeSendFailoverAlert("VPN/proxy detection (Proxycheck)", failures)
		}

		return false, err
	}

	atomic.StoreInt32(&consecutiveVPNCheckFailures, 0)
	return result.(bool), nil
}

func (s *VPNDetectionService) cacheResult(ctx context.Context, ip string, isSuspicious bool, ttl time.Duration) {
	setVPNL1(ip, isSuspicious, 1*time.Hour)
	cacheValStr := "no"
	if isSuspicious {
		cacheValStr = "yes"
	}
	redisKey := "vpn_check:" + ip
	CacheSet(ctx, redisKey, cacheValStr, ttl)
}

