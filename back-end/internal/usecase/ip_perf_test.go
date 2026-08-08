package usecase

import (
	"net"
	"net/netip"
	"testing"
)

var (
	testCIDRs = []string{
		"1.2.3.0/24",
		"103.21.244.0/22",
		"103.22.200.0/22",
		"103.31.4.0/22",
		"104.16.0.0/13",
		"104.24.0.0/14",
		"108.162.192.0/18",
		"131.0.72.0/22",
		"141.101.64.0/18",
		"162.158.0.0/15",
		"172.64.0.0/13",
		"173.245.48.0/20",
		"188.114.96.0/20",
		"190.93.240.0/20",
		"197.234.240.0/22",
		"198.41.128.0/17",
		"2400:cb00::/32",
		"2606:4700::/32",
		"2803:f800::/32",
		"2405:b500::/32",
		"2405:8100::/32",
		"2a06:98c0::/29",
		"2c0f:f248::/32",
	}

	testIPs = []string{
		"1.2.3.4",
		"104.18.2.1",
		"198.41.130.5",
		"8.8.8.8",
		"2606:4700:3030::ac43:2a7d",
		"2001:db8::1",
	}
)

func BenchmarkLegacyIPNetContains(b *testing.B) {
	var ipNets []*net.IPNet
	for _, cidr := range testCIDRs {
		_, ipNet, _ := net.ParseCIDR(cidr)
		ipNets = append(ipNets, ipNet)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		for _, ipStr := range testIPs {
			parsed := net.ParseIP(ipStr)
			if parsed != nil {
				_ = legacyContains(ipNets, parsed)
			}
		}
	}
}

func BenchmarkNetipPrefixContains(b *testing.B) {
	var prefixes []netip.Prefix
	for _, cidr := range testCIDRs {
		prefix, _ := netip.ParsePrefix(cidr)
		prefixes = append(prefixes, prefix)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		for _, ipStr := range testIPs {
			addr, err := netip.ParseAddr(ipStr)
			if err == nil {
				_ = netipContains(prefixes, addr)
			}
		}
	}
}

func legacyContains(ranges []*net.IPNet, ip net.IP) bool {
	for _, ipNet := range ranges {
		if ipNet.Contains(ip) {
			return true
		}
	}
	return false
}

func netipContains(ranges []netip.Prefix, addr netip.Addr) bool {
	for _, prefix := range ranges {
		if prefix.Contains(addr) {
			return true
		}
	}
	return false
}
