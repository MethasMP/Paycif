package usecase

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCloudflareIPRangeService_ContainsAfterRefresh(t *testing.T) {
	v4 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("1.2.3.0/24\n"))
	}))
	defer v4.Close()
	v6 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("2001:db8::/32\n"))
	}))
	defer v6.Close()

	oldV4, oldV6 := cloudflareIPv4URL, cloudflareIPv6URL
	cloudflareIPv4URL, cloudflareIPv6URL = v4.URL, v6.URL
	defer func() { cloudflareIPv4URL, cloudflareIPv6URL = oldV4, oldV6 }()

	svc := NewCloudflareIPRangeService()
	if err := svc.Refresh(context.Background()); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if !svc.Contains("1.2.3.4") {
		t.Errorf("expected 1.2.3.4 to be contained in the seeded v4 range")
	}
	if !svc.Contains("2001:db8::1") {
		t.Errorf("expected 2001:db8::1 to be contained in the seeded v6 range")
	}
	if svc.Contains("8.8.8.8") {
		t.Errorf("expected 8.8.8.8 not to be contained in any seeded range")
	}
}

func TestCloudflareIPRangeService_FailedRefreshKeepsLastKnownGood(t *testing.T) {
	good4 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("1.2.3.0/24\n"))
	}))
	defer good4.Close()
	good6 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("2001:db8::/32\n"))
	}))
	defer good6.Close()

	oldV4, oldV6 := cloudflareIPv4URL, cloudflareIPv6URL
	cloudflareIPv4URL, cloudflareIPv6URL = good4.URL, good6.URL

	svc := NewCloudflareIPRangeService()
	if err := svc.Refresh(context.Background()); err != nil {
		t.Fatalf("unexpected error on initial refresh: %v", err)
	}

	// Now point at a broken endpoint and refresh again.
	broken := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer broken.Close()
	cloudflareIPv4URL = broken.URL
	defer func() { cloudflareIPv4URL, cloudflareIPv6URL = oldV4, oldV6 }()

	if err := svc.Refresh(context.Background()); err == nil {
		t.Fatalf("expected an error when the v4 endpoint is broken")
	}

	if !svc.Contains("1.2.3.4") {
		t.Errorf("expected the last-known-good list to still be served after a failed refresh")
	}
}

func TestCloudflareIPRangeService_StartFailsWithNoCacheAndBrokenFetch(t *testing.T) {
	broken := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer broken.Close()

	oldV4, oldV6 := cloudflareIPv4URL, cloudflareIPv6URL
	cloudflareIPv4URL, cloudflareIPv6URL = broken.URL, broken.URL
	defer func() { cloudflareIPv4URL, cloudflareIPv6URL = oldV4, oldV6 }()

	svc := NewCloudflareIPRangeService()
	if err := svc.Start(context.Background()); err == nil {
		t.Fatalf("expected Start to error when there is no cache and the initial fetch fails")
		svc.Stop()
	}
}

func TestCloudflareIPRangeService_ContainsFalseBeforeAnyRefresh(t *testing.T) {
	svc := NewCloudflareIPRangeService()
	if svc.Contains("1.2.3.4") {
		t.Errorf("expected Contains to be false before any list has ever loaded")
	}
}

func BenchmarkCloudflareIPContains(b *testing.B) {
	v4 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("103.21.244.0/22\n103.22.200.0/22\n103.31.4.0/22\n141.101.64.0/18\n108.162.192.0/18\n190.93.240.0/20\n188.114.96.0/20\n197.234.240.0/22\n198.41.128.0/17\n162.158.0.0/15\n104.16.0.0/13\n104.24.0.0/14\n172.64.0.0/13\n131.0.72.0/22\n"))
	}))
	defer v4.Close()
	v6 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("2400:cb00::/32\n2606:4700::/32\n2803:f800::/32\n2405:b500::/32\n2405:8100::/32\n2a06:98c0::/29\n2c0f:f240::/28\n"))
	}))
	defer v6.Close()

	oldV4, oldV6 := cloudflareIPv4URL, cloudflareIPv6URL
	cloudflareIPv4URL, cloudflareIPv6URL = v4.URL, v6.URL
	defer func() { cloudflareIPv4URL, cloudflareIPv6URL = oldV4, oldV6 }()

	svc := NewCloudflareIPRangeService()
	if err := svc.Refresh(context.Background()); err != nil {
		b.Fatalf("unexpected error: %v", err)
	}

	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		svc.Contains("172.64.32.1")
	}
}
