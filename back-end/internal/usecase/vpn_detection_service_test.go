package usecase

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func init() {
	DisableRedisCacheForTesting = true
}

func withProxycheckTestServer(t *testing.T, handler http.HandlerFunc) *httptest.Server {
	t.Helper()
	server := httptest.NewServer(handler)
	oldKey, oldBase := proxycheckAPIKey, proxycheckBaseURL
	proxycheckAPIKey = "test-key"
	proxycheckBaseURL = server.URL
	t.Cleanup(func() {
		server.Close()
		proxycheckAPIKey, proxycheckBaseURL = oldKey, oldBase
	})
	return server
}

func jsonProxycheckHandler(body string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(body))
	}
}

func TestVPNDetection_ProxyYesIsSuspicious(t *testing.T) {
	ClearVPNL1Cache()
	withProxycheckTestServer(t, jsonProxycheckHandler(`{
		"status": "ok",
		"1.2.3.4": {
			"proxy": "yes",
			"type": "VPN"
		}
	}`))

	svc := NewVPNDetectionService()
	suspicious, err := svc.IsSuspicious(context.Background(), "1.2.3.4")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !suspicious {
		t.Errorf("expected proxy=yes to be flagged suspicious")
	}
}

func TestVPNDetection_ProxyNoIsNotSuspicious(t *testing.T) {
	ClearVPNL1Cache()
	withProxycheckTestServer(t, jsonProxycheckHandler(`{
		"status": "ok",
		"1.2.3.4": {
			"proxy": "no"
		}
	}`))

	svc := NewVPNDetectionService()
	suspicious, err := svc.IsSuspicious(context.Background(), "1.2.3.4")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if suspicious {
		t.Errorf("expected proxy=no to be clean")
	}
}

func TestVPNDetection_FailsOnAPIError(t *testing.T) {
	ClearVPNL1Cache()
	withProxycheckTestServer(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	})

	svc := NewVPNDetectionService()
	_, err := svc.IsSuspicious(context.Background(), "1.2.3.4")
	if err == nil {
		t.Fatalf("expected an error on API failure")
	}
	var quotaErr quotaExceededError
	if errors.As(err, &quotaErr) {
		t.Errorf("expected a generic failure, not a quota-exceeded error, for a plain 500")
	}
}

func TestVPNDetection_QuotaExceededIsDistinguishable(t *testing.T) {
	ClearVPNL1Cache()
	withProxycheckTestServer(t, jsonProxycheckHandler(`{
		"status": "denied",
		"message": "Your daily query limit has been exceeded."
	}`))

	svc := NewVPNDetectionService()
	_, err := svc.IsSuspicious(context.Background(), "1.2.3.4")
	if err == nil {
		t.Fatalf("expected an error when the API reports quota exceeded")
	}
	var quotaErr quotaExceededError
	if !errors.As(err, &quotaErr) {
		t.Errorf("expected a quotaExceededError, got %T: %v", err, err)
	}
}

func TestVPNDetection_MissingAPIKeyFails(t *testing.T) {
	ClearVPNL1Cache()
	server := httptest.NewServer(func() http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			t.Errorf("should not call Proxycheck at all when no API key is configured")
		}
	}())
	defer server.Close()

	oldKey, oldBase := proxycheckAPIKey, proxycheckBaseURL
	oldIpqsKey := ipqsAPIKey
	proxycheckAPIKey = ""
	ipqsAPIKey = ""
	proxycheckBaseURL = server.URL
	defer func() {
		proxycheckAPIKey, proxycheckBaseURL = oldKey, oldBase
		ipqsAPIKey = oldIpqsKey
	}()

	svc := NewVPNDetectionService()
	_, err := svc.IsSuspicious(context.Background(), "1.2.3.4")
	if err == nil {
		t.Fatalf("expected an error when both API keys are unset")
	}
}

func TestVPNDetection_IPQSFallbackWhenProxycheckFails(t *testing.T) {
	ClearVPNL1Cache()
	proxyServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer proxyServer.Close()

	ipqsServer := httptest.NewServer(jsonIPQSHandler(`{"success": true, "active_vpn": true}`))
	defer ipqsServer.Close()

	oldPKey, oldPBase := proxycheckAPIKey, proxycheckBaseURL
	oldIKey, oldIBase := ipqsAPIKey, ipqsBaseURL

	proxycheckAPIKey = "p-key"
	proxycheckBaseURL = proxyServer.URL
	ipqsAPIKey = "i-key"
	ipqsBaseURL = ipqsServer.URL

	defer func() {
		proxycheckAPIKey, proxycheckBaseURL = oldPKey, oldPBase
		ipqsAPIKey, ipqsBaseURL = oldIKey, oldIBase
		ClearVPNL1Cache()
	}()

	svc := NewVPNDetectionService()
	suspicious, err := svc.IsSuspicious(context.Background(), "1.2.3.4")
	if err != nil {
		t.Fatalf("expected fallback to succeed, got err: %v", err)
	}
	if !suspicious {
		t.Errorf("expected IPQS fallback to flag IP as suspicious")
	}
}

func TestBoundedLRUCache_CapacityEviction(t *testing.T) {
	cache := newBoundedLRUCache(2) // capacity 2

	cache.Put("ip1", true, 10*time.Second)
	cache.Put("ip2", false, 10*time.Second)

	// Access ip1 so ip1 becomes most recently used, leaving ip2 as oldest
	if _, found := cache.Get("ip1"); !found {
		t.Errorf("expected ip1 to be found")
	}

	// Add ip3 -> ip2 (least recently used) should be evicted
	cache.Put("ip3", true, 10*time.Second)

	if _, found := cache.Get("ip2"); found {
		t.Errorf("expected ip2 to be evicted due to capacity limit")
	}
	if _, found := cache.Get("ip1"); !found {
		t.Errorf("expected ip1 to remain in cache")
	}
	if _, found := cache.Get("ip3"); !found {
		t.Errorf("expected ip3 to exist in cache")
	}
}

func BenchmarkVPNCacheKey(b *testing.B) {
	ip := "192.168.1.100"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "vpn_check:" + ip
	}
}
