package usecase_test

import (
	"fmt"
	"testing"
)

// BenchmarkCacheKeySprintf benchmarks the old cache key generation pattern
func BenchmarkCacheKeySprintf(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", fromCurr, toCurr)
	}
}

// BenchmarkCacheKeyConcat benchmarks the optimized manual string concatenation pattern
func BenchmarkCacheKeyConcat(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + fromCurr + ":" + toCurr
	}
}

// BenchmarkDescriptionSprintf benchmarks the old PromptPay description formatting pattern
func BenchmarkDescriptionSprintf(b *testing.B) {
	recipientName := "John Doe"
	promptPayID := "1234567890"
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("PromptPay to %s (%s)", recipientName, promptPayID)
	}
}

// BenchmarkDescriptionConcat benchmarks the optimized manual string concatenation pattern for descriptions
func BenchmarkDescriptionConcat(b *testing.B) {
	recipientName := "John Doe"
	promptPayID := "1234567890"
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = "PromptPay to " + recipientName + " (" + promptPayID + ")"
	}
}
