package usecase

import (
	"context"
	"fmt"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
)

// BenchmarkCacheKeyConcat benchmarks the optimized string concatenation for cache key generation
func BenchmarkCacheKeyConcat(b *testing.B) {
	fromCurr := "usd"
	toCurr := "thb"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fromUpper := strings.ToUpper(fromCurr)
		toUpper := strings.ToUpper(toCurr)
		_ = "rate:" + fromUpper + ":" + toUpper
	}
}

// BenchmarkCacheKeySprintf benchmarks the slow fmt.Sprintf pattern for cache key generation
func BenchmarkCacheKeySprintf(b *testing.B) {
	fromCurr := "usd"
	toCurr := "thb"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", fromCurr, toCurr)
	}
}

// BenchmarkPayloadConcat benchmarks the optimized string concatenation for outbox payload
func BenchmarkPayloadConcat(b *testing.B) {
	newTxID := uuid.New()
	amount := 123.45
	userID := uuid.New()
	merchant := "TestMerchant"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = `{"transaction_id": "` + newTxID.String() + `", "amount": ` + strconv.FormatFloat(amount, 'f', -1, 64) + `, "user_id": "` + userID.String() + `", "merchant": "` + merchant + `"}`
	}
}

// BenchmarkPayloadSprintf benchmarks the slow fmt.Sprintf pattern for outbox payload
func BenchmarkPayloadSprintf(b *testing.B) {
	newTxID := uuid.New()
	amount := 123.45
	userID := uuid.New()
	merchant := "TestMerchant"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf(`{"transaction_id": "%s", "amount": %f, "user_id": "%s", "merchant": "%s"}`, newTxID, amount, userID, merchant)
	}
}

// BenchmarkGetExchangeRateCacheHit benchmarks GetExchangeRate on the hot path (local cache hit)
func BenchmarkGetExchangeRateCacheHit(b *testing.B) {
	s := &WalletService{}
	ctx := context.Background()
	fromCurr := "USD"
	toCurr := "THB"
	cacheKey := "rate:" + fromCurr + ":" + toCurr

	response := &ExchangeRateResponse{
		FromCurrency: fromCurr,
		ToCurrency:   toCurr,
		ProviderRate: 35.5,
		UpdatedAt:    time.Now(),
	}

	s.localRateCache.Store(cacheKey, localCacheItem{
		Response:  response,
		ExpiresAt: time.Now().Add(1 * time.Hour),
	})

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := s.GetExchangeRate(ctx, fromCurr, toCurr)
		if err != nil {
			b.Fatalf("expected no error, got %v", err)
		}
	}
}
