package usecase

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestGetExchangeRate_CacheFragmentation(t *testing.T) {
	s := &WalletService{}

	// Seed the cache with uppercase key
	from := "USD"
	to := "THB"
	cacheKey := fmt.Sprintf("rate:%s:%s", from, to)
	expectedResponse := &ExchangeRateResponse{
		FromCurrency: from,
		ToCurrency:   to,
		ProviderRate: 35.0,
		UpdatedAt:    time.Now(),
	}

	s.localRateCache.Store(cacheKey, localCacheItem{
		Response:  expectedResponse,
		ExpiresAt: time.Now().Add(time.Minute),
	})

	// Try to fetch with lowercase - this should now SUCCEED after optimization
	resp, err := s.GetExchangeRate(context.Background(), "usd", "thb")
	assert.NoError(t, err)
	assert.Equal(t, expectedResponse, resp)

	// Now try with exact match - this should SUCCEED
	resp, err = s.GetExchangeRate(context.Background(), "USD", "THB")
	assert.NoError(t, err)
	assert.Equal(t, expectedResponse, resp)
}
