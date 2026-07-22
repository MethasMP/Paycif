package usecase_test

import (
	"fmt"
	"testing"
)

// BenchmarkCacheKeySprintf benchmarks cache key generation using fmt.Sprintf.
func BenchmarkCacheKeySprintf(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", fromCurr, toCurr)
	}
}

// BenchmarkCacheKeyConcatenate benchmarks cache key generation using string concatenation.
func BenchmarkCacheKeyConcatenate(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + fromCurr + ":" + toCurr
	}
}

// BenchmarkPromptPayDescriptionSprintf benchmarks PromptPay description formatting using fmt.Sprintf.
func BenchmarkPromptPayDescriptionSprintf(b *testing.B) {
	recipientName := "Somsri"
	promptPayID := "0812345678"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("PromptPay to %s (%s)", recipientName, promptPayID)
	}
}

// BenchmarkPromptPayDescriptionConcatenate benchmarks PromptPay description formatting using string concatenation.
func BenchmarkPromptPayDescriptionConcatenate(b *testing.B) {
	recipientName := "Somsri"
	promptPayID := "0812345678"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "PromptPay to " + recipientName + " (" + promptPayID + ")"
	}
}
