package middleware

import (
	"fmt"
	"strconv"
	"testing"
)

func BenchmarkRateLimiterKeySprintf(b *testing.B) {
	identifier := "user_123456789"
	currentMinute := int64(29481023)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkRateLimiterKeyConcat(b *testing.B) {
	identifier := "user_123456789"
	currentMinute := int64(29481023)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

func TestRateLimiterKeyFormatting(t *testing.T) {
	identifier := "user_123456789"
	currentMinute := int64(29481023)

	expected := fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	actual := "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)

	if expected != actual {
		t.Errorf("expected %q, got %q", expected, actual)
	}
}
