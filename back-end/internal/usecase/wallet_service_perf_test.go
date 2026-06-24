package usecase

import (
	"fmt"
	"testing"
)

func BenchmarkCacheKeySprintf(b *testing.B) {
	fromCurr := "usd"
	toCurr := "thb"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", fromCurr, toCurr)
	}
}

func BenchmarkCacheKeyConcat(b *testing.B) {
	fromCurr := "usd"
	toCurr := "thb"
	for i := 0; i < b.N; i++ {
		_ = "rate:" + fromCurr + ":" + toCurr
	}
}
