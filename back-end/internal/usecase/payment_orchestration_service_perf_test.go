package usecase

import (
	"context"
	"testing"
	"time"
)

func BenchmarkGetExchangeRate(b *testing.B) {
	service := &PaymentOrchestrationService{}

	fromCurr := "USD"
	toCurr := "THB"
	// Seed the cache with both format styles (to be safe against different key formats before/after optimization)
	resp := &ExchangeRateResponse{
		FromCurrency: fromCurr,
		ToCurrency:   toCurr,
		ProviderRate: 35.5,
		UpdatedAt:    time.Now(),
	}

	service.localRateCache.Store("rate:USD:THB", localCacheItem{
		Response:  resp,
		ExpiresAt: time.Now().Add(5 * time.Minute),
	})

	ctx := context.Background()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = service.GetExchangeRate(ctx, fromCurr, toCurr)
	}
}
