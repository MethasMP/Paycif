package usecase

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestGetExchangeRate_Cached(t *testing.T) {
	// Initialize PaymentOrchestrationService with DB=nil to prove it retrieves from cache.
	s := &PaymentOrchestrationService{}

	fromCurr := "USD"
	toCurr := "THB"
	cacheKey := "rate:" + fromCurr + ":" + toCurr

	expectedResponse := &ExchangeRateResponse{
		FromCurrency: fromCurr,
		ToCurrency:   toCurr,
		ProviderRate: 35.5,
		UpdatedAt:    time.Now(),
	}

	// Manually seed the cache
	s.localRateCache.Store(cacheKey, localCacheItem{
		Response:  expectedResponse,
		ExpiresAt: time.Now().Add(5 * time.Minute),
	})

	// Retrieve the rate
	resp, err := s.GetExchangeRate(context.Background(), fromCurr, toCurr)
	assert.NoError(t, err)
	assert.Equal(t, expectedResponse, resp)
}

func BenchmarkGetExchangeRateCacheKeyConcat(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + fromCurr + ":" + toCurr
	}
}

func BenchmarkGetExchangeRateCacheKeySprintf(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", fromCurr, toCurr)
	}
}
