package usecase

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestGetExchangeRate_CacheNormalization(t *testing.T) {
	svc := &WalletService{}

	// Manually populate the cache with a normalized key
	normalizedKey := "rate:USD:THB"
	response := &ExchangeRateResponse{
		FromCurrency: "USD",
		ToCurrency:   "THB",
		ProviderRate: 35.0,
		UpdatedAt:    time.Now(),
	}
	svc.localRateCache.Store(normalizedKey, localCacheItem{
		Response:  response,
		ExpiresAt: time.Now().Add(1 * time.Hour),
	})

	ctx := context.Background()

	t.Run("Cache hit with lowercase input", func(t *testing.T) {
		// Should hit the cache because "usd" and "thb" are normalized to "USD" and "THB"
		resp, err := svc.GetExchangeRate(ctx, "usd", "thb")

		// If it tries to call DB, it will panic because s.DB is nil.
		// If it hits the cache, it returns before the DB call.
		assert.NoError(t, err)
		assert.Equal(t, response, resp)
	})

	t.Run("Cache hit with mixed case input", func(t *testing.T) {
		resp, err := svc.GetExchangeRate(ctx, "Usd", "tHb")
		assert.NoError(t, err)
		assert.Equal(t, response, resp)
	})

	t.Run("Cache miss with different currency", func(t *testing.T) {
		// This should attempt to call the DB and panic (since s.DB is nil),
		// confirming it doesn't hit the "USD:THB" cache entry.
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("Expected panic due to nil DB on cache miss, but it didn't panic")
			}
		}()
		_, _ = svc.GetExchangeRate(ctx, "EUR", "THB")
	})
}
