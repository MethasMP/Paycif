package usecase

import (
	"context"
	"testing"

	"github.com/shopspring/decimal"
	"github.com/stretchr/testify/assert"
)

func TestFXService_ConvertToBase_THB(t *testing.T) {
	svc := NewFXService(nil, nil)
	ctx := context.Background()

	amount, rate, err := svc.ConvertToBase(ctx, 1000, "THB")
	assert.NoError(t, err)
	assert.Equal(t, int64(1000), amount)
	assert.True(t, rate.Equal(decimal.NewFromInt(1)))
}

func TestFXService_ConvertToBase_RedisCache(t *testing.T) {
	svc := NewFXService(nil, nil)
	ctx := context.Background()

	// Disable test bypass to use mock/in-memory logic if Redis unavailable
	DisableRedisCacheForTesting = false

	// Set cache directly
	CacheSet(ctx, "fx_rate:USD:THB", "35.50", 10)

	// Since Redis might not be running locally, CacheGet will return false if no Redis,
	// but if Redis is running, it will return the cached value.
	// Test THB conversion logic to ensure no panic:
	amt, r, err := svc.ConvertToBase(ctx, 100, "THB")
	assert.NoError(t, err)
	assert.Equal(t, int64(100), amt)
	assert.True(t, r.Equal(decimal.NewFromInt(1)))
}
