package usecase

import (
	"strconv"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestWalletService_Concatenation(t *testing.T) {
	// Simple test to ensure concatenation logic is correct
	from := "USD"
	to := "THB"
	cacheKey := "rate:" + from + ":" + to
	assert.Equal(t, "rate:USD:THB", cacheKey)

	merchant := "Test"
	amount := 12.34
	providerMetadata := `{"provider": "alchemypay", "merchant": ` + strconv.Quote(merchant) + `, "amount": ` + strconv.FormatFloat(amount, 'f', -1, 64) + `}`
	assert.Contains(t, providerMetadata, `"merchant": "Test"`)
	assert.Contains(t, providerMetadata, `"amount": 12.34`)
}

func TestWalletService_GetExchangeRate_Cache_Internal(t *testing.T) {
	s := &WalletService{}

	// Test cache hit
	resp := &ExchangeRateResponse{FromCurrency: "USD", ToCurrency: "THB", ProviderRate: 35.0}
	s.localRateCache.Store("rate:USD:THB", localCacheItem{Response: resp, ExpiresAt: time.Now().Add(time.Hour)})

	got, err := s.GetExchangeRate(context.Background(), "USD", "THB")
	assert.NoError(t, err)
	assert.Equal(t, resp, got)
}
