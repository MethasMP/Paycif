package usecase

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"testing"
)

func BenchmarkCloudflareContains(b *testing.B) {
	// Setup a service with some CIDRs
	v4 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("1.2.3.0/24\n192.168.1.0/24\n10.0.0.0/8\n"))
	}))
	defer v4.Close()
	v6 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("2001:db8::/32\n"))
	}))
	defer v6.Close()

	oldV4, oldV6 := SetCloudflareIPURLsForTest(v4.URL, v6.URL)
	defer SetCloudflareIPURLsForTest(oldV4, oldV6)

	svc := NewCloudflareIPRangeService()
	if err := svc.Refresh(context.Background()); err != nil {
		b.Fatalf("failed to refresh: %v", err)
	}

	ips := []string{"1.2.3.4", "192.168.1.100", "10.5.5.5", "2001:db8::1", "8.8.8.8", "invalid-ip"}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		for _, ip := range ips {
			_ = svc.Contains(ip)
		}
	}
}

func BenchmarkIsInThailandCIDR(b *testing.B) {
	// Initialize thCIDRBlocks manually to bypass loading
	cidr1, _ := netip.ParsePrefix("1.2.3.0/24")
	cidr2, _ := netip.ParsePrefix("101.109.0.0/16")
	cidr3, _ := netip.ParsePrefix("110.164.0.0/16")
	cidr4, _ := netip.ParsePrefix("2001:db8::/32")
	thCIDRBlocks = []netip.Prefix{cidr1, cidr2, cidr3, cidr4}
	thCIDRBlocksLoaded = 1

	ips := []string{"1.2.3.4", "101.109.0.5", "2001:db8::1", "8.8.8.8", "110.164.0.1"}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		for _, ip := range ips {
			_ = IsInThailandCIDR(ip)
		}
	}
}

func BenchmarkTruncateIP(b *testing.B) {
	ips := []string{"1.2.3.4", "192.168.1.100", "2001:db8::1", "invalid-ip"}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		for _, ip := range ips {
			_ = TruncateIP(ip)
		}
	}
}
