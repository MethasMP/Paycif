package usecase

import (
	"fmt"
	"strings"
	"testing"
)

func BenchmarkCacheKeySprintf(b *testing.B) {
	from := "USD"
	to := "THB"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", from, to)
	}
}

func BenchmarkCacheKeyConcat(b *testing.B) {
	from := "USD"
	to := "THB"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + from + ":" + to
	}
}

func BenchmarkCacheKeyConcatNormalized(b *testing.B) {
	from := "usd"
	to := "thb"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + strings.ToUpper(from) + ":" + strings.ToUpper(to)
	}
}
