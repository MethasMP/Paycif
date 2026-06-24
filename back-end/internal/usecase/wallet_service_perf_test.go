package usecase_test

import (
	"fmt"
	"strings"
	"testing"
)

func BenchmarkCacheKeySprintf(b *testing.B) {
	from := "USD"
	to := "THB"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", from, to)
	}
}

func BenchmarkCacheKeyConcat(b *testing.B) {
	from := "USD"
	to := "THB"
	for i := 0; i < b.N; i++ {
		_ = "rate:" + from + ":" + to
	}
}

func BenchmarkCacheKeyConcatNormalized(b *testing.B) {
	from := "usd"
	to := "thb"
	for i := 0; i < b.N; i++ {
		f := strings.ToUpper(from)
		t := strings.ToUpper(to)
		_ = "rate:" + f + ":" + t
	}
}

func BenchmarkPayoutDescriptionSprintf(b *testing.B) {
	name := "John Doe"
	id := "0812345678"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("PromptPay to %s (%s)", name, id)
	}
}

func BenchmarkPayoutDescriptionConcat(b *testing.B) {
	name := "John Doe"
	id := "0812345678"
	for i := 0; i < b.N; i++ {
		_ = "PromptPay to " + name + " (" + id + ")"
	}
}
