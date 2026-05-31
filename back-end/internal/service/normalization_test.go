package service

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestGetExchangeRate_Normalization_Internal(t *testing.T) {
	s := &WalletService{}

	// Pre-populate cache with uppercase keys
	expectedResp := &ExchangeRateResponse{
		FromCurrency: "USD",
		ToCurrency:   "THB",
		ProviderRate: 35.0,
		UpdatedAt:    time.Now(),
	}

	cacheKey := "rate:USD:THB"
	s.localRateCache.Store(cacheKey, localCacheItem{
		Response:  expectedResp,
		ExpiresAt: time.Now().Add(1 * time.Hour),
	})

	// Test mixed case
	ctx := context.Background()
	resp, err := s.GetExchangeRate(ctx, "usd", "thb")

	assert.NoError(t, err)
	assert.Equal(t, expectedResp, resp, "Should hit cache even with lowercase input")

	resp2, err := s.GetExchangeRate(ctx, "UsD", "ThB")
	assert.NoError(t, err)
	assert.Equal(t, expectedResp, resp2, "Should hit cache even with mixed case input")
}
