package usecase

import (
	"fmt"
	"strconv"
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
		_ = `{"provider": "alchemypay", "merchant": "` + merchant + `", "amount": ` + strconv.FormatFloat(amount, 'f', -1, 64) + `}`
	}
}

func BenchmarkDescriptionSprintf(b *testing.B) {
	name := "John Doe"
	id := "1234567890"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("PromptPay to %s (%s)", name, id)
	}
}

func BenchmarkDescriptionConcat(b *testing.B) {
	name := "John Doe"
	id := "1234567890"
	for i := 0; i < b.N; i++ {
		_ = "PromptPay to " + name + " (" + id + ")"
	}
}
