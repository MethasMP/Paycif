package usecase_test

import (
	"fmt"
	"testing"
)

func BenchmarkVPNKeySprintf(b *testing.B) {
	ip := "192.168.1.100"
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("vpn_check:%s", ip)
	}
}

func BenchmarkVPNKeyConcat(b *testing.B) {
	ip := "192.168.1.100"
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = "vpn_check:" + ip
	}
}

func BenchmarkFXKeySprintf(b *testing.B) {
	upperCurr := "USD"
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("fx_rate:%s:THB", upperCurr)
	}
}

func BenchmarkFXKeyConcat(b *testing.B) {
	upperCurr := "USD"
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = "fx_rate:" + upperCurr + ":THB"
	}
}

func BenchmarkGeoKeySprintf(b *testing.B) {
	ip := "192.168.1.100"
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("geo_country:%s", ip)
	}
}

func BenchmarkGeoKeyConcat(b *testing.B) {
	ip := "192.168.1.100"
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = "geo_country:" + ip
	}
}
