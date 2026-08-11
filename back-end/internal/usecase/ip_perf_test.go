package usecase

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func BenchmarkTruncateIP(b *testing.B) {
	ips := []string{
		"203.0.113.42",
		"8.8.8.8",
		"2001:db8:85a3::8a2e:370:7334",
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		for _, ip := range ips {
			_ = TruncateIP(ip)
		}
	}
}

func BenchmarkContains(b *testing.B) {
	v4 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("1.2.3.0/24\n"))
	}))
	defer v4.Close()
	v6 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("2001:db8::/32\n"))
	}))
	defer v6.Close()

	oldV4, oldV6 := cloudflareIPv4URL, cloudflareIPv6URL
	cloudflareIPv4URL, cloudflareIPv6URL = v4.URL, v6.URL
	defer func() { cloudflareIPv4URL, cloudflareIPv6URL = oldV4, oldV6 }()

	svc := NewCloudflareIPRangeService()
	if err := svc.Refresh(context.Background()); err != nil {
		b.Fatalf("failed to refresh: %v", err)
	}

	ips := []string{
		"1.2.3.4",
		"2001:db8::1",
		"8.8.8.8",
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		for _, ip := range ips {
			_ = svc.Contains(ip)
		}
	}
}

func BenchmarkIsInThailandCIDR(b *testing.B) {
	// Seed some mock subnet data
	// Let's call LoadTHCIDRBlocks first so that file reads/downloads are cached
	// and we only benchmark the Contains logic.
	LoadTHCIDRBlocks()

	ips := []string{
		"1.2.3.4",
		"182.52.0.1", // Typically a TH IP
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		for _, ip := range ips {
			_ = IsInThailandCIDR(ip)
		}
	}
}
