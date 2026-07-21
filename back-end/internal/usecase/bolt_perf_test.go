package usecase_test

import (
	"fmt"
	"strconv"
	"testing"

	"github.com/google/uuid"
)

// BenchmarkCacheKey_Sprintf measures the performance of fmt.Sprintf for cache key generation.
func BenchmarkCacheKey_Sprintf(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", fromCurr, toCurr)
	}
}

// BenchmarkCacheKey_Concat measures the performance of manual string concatenation for cache key generation.
func BenchmarkCacheKey_Concat(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + fromCurr + ":" + toCurr
	}
}

// BenchmarkMetadata_Sprintf measures the performance of fmt.Sprintf for metadata construction.
func BenchmarkMetadata_Sprintf(b *testing.B) {
	merchant := "AlchemyPay Test Merchant"
	amount := 125.50
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf(`{"provider": "alchemypay", "merchant": "%s", "amount": %f}`, merchant, amount)
	}
}

// BenchmarkMetadata_Concat measures the performance of manual string concatenation for metadata construction.
func BenchmarkMetadata_Concat(b *testing.B) {
	merchant := "AlchemyPay Test Merchant"
	amount := 125.50
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = `{"provider": "alchemypay", "merchant": "` + merchant + `", "amount": ` + strconv.FormatFloat(amount, 'f', -1, 64) + `}`
	}
}

// BenchmarkOutboxPayload_Sprintf measures the performance of fmt.Sprintf for outbox payload construction.
func BenchmarkOutboxPayload_Sprintf(b *testing.B) {
	newTxID := uuid.New()
	amount := 125.50
	userID := uuid.New()
	merchant := "AlchemyPay Test Merchant"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf(`{"transaction_id": "%s", "amount": %f, "user_id": "%s", "merchant": "%s"}`, newTxID, amount, userID, merchant)
	}
}

// BenchmarkOutboxPayload_Concat measures the performance of manual string concatenation for outbox payload construction.
func BenchmarkOutboxPayload_Concat(b *testing.B) {
	newTxID := uuid.New()
	amount := 125.50
	userID := uuid.New()
	merchant := "AlchemyPay Test Merchant"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = `{"transaction_id": "` + newTxID.String() + `", "amount": ` + strconv.FormatFloat(amount, 'f', -1, 64) + `, "user_id": "` + userID.String() + `", "merchant": "` + merchant + `"}`
	}
}

// BenchmarkPromptPayDescription_Sprintf measures description formatting using fmt.Sprintf.
func BenchmarkPromptPayDescription_Sprintf(b *testing.B) {
	recipientName := "Somsak Somboon"
	promptPayID := "0812345678"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("PromptPay to %s (%s)", recipientName, promptPayID)
	}
}

// BenchmarkPromptPayDescription_Concat measures description formatting using manual string concatenation.
func BenchmarkPromptPayDescription_Concat(b *testing.B) {
	recipientName := "Somsak Somboon"
	promptPayID := "0812345678"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "PromptPay to " + recipientName + " (" + promptPayID + ")"
	}
}
