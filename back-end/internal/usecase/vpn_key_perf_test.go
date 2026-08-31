package usecase

import (
	"fmt"
	"testing"
)

func BenchmarkVPN_Sprintf(b *testing.B) {
	ip := "192.168.1.100"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("vpn_check:%s", ip)
	}
}

func BenchmarkVPN_Concat(b *testing.B) {
	ip := "192.168.1.100"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "vpn_check:" + ip
	}
}
