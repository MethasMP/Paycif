package usecase_test

import (
	"fmt"
	"strings"
	"testing"
)

func BenchmarkCacheKeySprintf(b *testing.B) {
	from := "usd"
	to := "thb"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", from, to)
	}
}

func BenchmarkCacheKeyConcat(b *testing.B) {
	from := "usd"
	to := "thb"
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
		f := strings.ToUpper(from)
		t := strings.ToUpper(to)
		_ = "rate:" + f + ":" + t
	}
}
