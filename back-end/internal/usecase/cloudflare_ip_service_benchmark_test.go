package usecase

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"testing"
)

func BenchmarkCloudflareIPRangeService_Contains_Classic(b *testing.B) {
	// This benchmark represents the old way (simulated using netip for comparison if we want, or we keep it for historic baseline)
	v4 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("173.245.48.0/20\n103.21.244.0/22\n103.22.200.0/22\n103.31.4.0/22\n141.101.64.0/18\n108.162.192.0/18\n190.93.240.0/20\n188.114.96.0/20\n197.234.240.0/22\n198.41.128.0/17\n162.158.0.0/15\n104.16.0.0/13\n104.24.0.0/14\n172.64.0.0/13\n131.0.72.0/22\n"))
	}))
	defer v4.Close()
	v6 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("2400:cb00::/32\n2606:4700::/32\n2803:f800::/32\n2405:b500::/32\n2405:8100::/32\n2a06:98c0::/29\n2c0f:f248::/32\n"))
	}))
	defer v6.Close()

	oldV4, oldV6 := cloudflareIPv4URL, cloudflareIPv6URL
	cloudflareIPv4URL, cloudflareIPv6URL = v4.URL, v6.URL
	defer func() { cloudflareIPv4URL, cloudflareIPv6URL = oldV4, oldV6 }()

	svc := NewCloudflareIPRangeService()
	if err := svc.Refresh(context.Background()); err != nil {
		b.Fatalf("unexpected error: %v", err)
	}

	testIPs := []string{
		"173.245.48.1",  // In range (IPv4, first block)
		"162.158.5.12",  // In range (IPv4, middle block)
		"172.65.10.20",  // In range (IPv4, late block)
		"8.8.8.8",       // Out of range (IPv4)
		"2400:cb00::1",  // In range (IPv6)
		"2001:db8::1",   // Out of range (IPv6)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		ip := testIPs[i%len(testIPs)]
		_ = svc.Contains(ip)
	}
}

func BenchmarkIsInThailandCIDR(b *testing.B) {
	LoadTHCIDRBlocks()
	testIPs := []string{
		"203.0.113.42",
		"1.2.3.4",
		"8.8.8.8",
		"127.0.0.1",
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = IsInThailandCIDR(testIPs[i%len(testIPs)])
	}
}

func BenchmarkIsInThailandCIDR_WithLoadedSubnets_Netip(b *testing.B) {
	oldBlocks := thCIDRBlocks
	defer func() {
		thCIDRBlocks = oldBlocks
	}()

	// Seed 100 mock subnets using netip.Prefix
	var prefixes []netip.Prefix
	for i := 0; i < 100; i++ {
		p, _ := netip.ParsePrefix("182.52.0.0/16")
		prefixes = append(prefixes, p)
	}
	thCIDRBlocks = prefixes

	testIPs := []string{
		"182.52.5.12",
		"1.2.3.4",
		"8.8.8.8",
		"127.0.0.1",
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		parsed, err := netip.ParseAddr(testIPs[i%len(testIPs)])
		if err != nil {
			continue
		}
		found := false
		for _, prefix := range thCIDRBlocks {
			if prefix.Contains(parsed) {
				found = true
				break
			}
		}
		_ = found
	}
}
