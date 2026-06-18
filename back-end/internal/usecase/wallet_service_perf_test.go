package usecase

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestGetExchangeRate_CacheNormalization(t *testing.T) {
	svc := &WalletService{}

	ctx := context.Background()

	// Pre-fill the cache with a normalized key
	resp := &ExchangeRateResponse{
		FromCurrency: "USD",
		ToCurrency:   "THB",
		ProviderRate: 35.5,
		UpdatedAt:    time.Now(),
	}
	svc.localRateCache.Store("rate:USD:THB", localCacheItem{
		Response:  resp,
		ExpiresAt: time.Now().Add(1 * time.Minute),
	})

	// Test with mixed case - should HIT cache and NOT call DB (which is nil and would panic)
	res, err := svc.GetExchangeRate(ctx, "uSd", "tHb")

	assert.NoError(t, err)
	assert.Equal(t, resp, res)
	assert.Equal(t, "USD", res.FromCurrency)
	assert.Equal(t, "THB", res.ToCurrency)
}

var sink string

func BenchmarkGetExchangeRate_KeyGeneration_Concat(b *testing.B) {
	from := "USD"
	to := "THB"
	var r string
	for i := 0; i < b.N; i++ {
		r = "rate:" + from + ":" + to
	}
	sink = r
}

func BenchmarkGetExchangeRate_KeyGeneration_Sprintf(b *testing.B) {
	from := "USD"
	to := "THB"
	var r string
	for i := 0; i < b.N; i++ {
		r = fmt.Sprintf("rate:%s:%s", from, to)
	}
	sink = r
}
