package usecase

import (
	"fmt"
	"testing"
)

func BenchmarkSprintf(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", fromCurr, toCurr)
	}
}

func BenchmarkConcat(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"
	for i := 0; i < b.N; i++ {
		_ = "rate:" + fromCurr + ":" + toCurr
	}
}
