package middleware

import (
	"fmt"
	"strconv"
	"testing"
)

func generateRateKeyBaseline(identifier string, minute int64) string {
	return fmt.Sprintf("rate:%s:%d", identifier, minute)
}

func generateRateKeyOptimized(identifier string, minute int64) string {
	return "rate:" + identifier + ":" + strconv.FormatInt(minute, 10)
}

func TestRateLimiterKeyFormatting(t *testing.T) {
	identifier := "user_12345678-abcd-1234-efgh-1234567890ab"
	minute := int64(29560000)

	baseline := generateRateKeyBaseline(identifier, minute)
	optimized := generateRateKeyOptimized(identifier, minute)

	if baseline != optimized {
		t.Fatalf("Rate limiter key mismatch: baseline %q != optimized %q", baseline, optimized)
	}
}

func BenchmarkRateLimiterKey_Baseline(b *testing.B) {
	identifier := "user_12345678-abcd-1234-efgh-1234567890ab"
	minute := int64(29560000)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = generateRateKeyBaseline(identifier, minute)
	}
}

func BenchmarkRateLimiterKey_Optimized(b *testing.B) {
	identifier := "user_12345678-abcd-1234-efgh-1234567890ab"
	minute := int64(29560000)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = generateRateKeyOptimized(identifier, minute)
	}
}
