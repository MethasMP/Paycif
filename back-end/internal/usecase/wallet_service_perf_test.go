package usecase_test

import (
	"fmt"
	"strconv"
	"testing"
)

func BenchmarkCacheKeySprintf(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", fromCurr, toCurr)
	}
}

func BenchmarkCacheKeyConcat(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"
	for i := 0; i < b.N; i++ {
		_ = "rate:" + fromCurr + ":" + toCurr
	}
}

func BenchmarkJSONSprintf(b *testing.B) {
	merchant := "Test Merchant"
	amount := 123.45
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf(`{"provider": "alchemypay", "merchant": "%s", "amount": %f}`, merchant, amount)
	}
}

func BenchmarkJSONConcat(b *testing.B) {
	merchant := "Test Merchant"
	amount := 123.45
	for i := 0; i < b.N; i++ {
		_ = `{"provider": "alchemypay", "merchant": "` + merchant + `", "amount": ` + strconv.FormatFloat(amount, 'f', 6, 64) + `}`
	}
}
