package usecase_test

import (
	"fmt"
	"strconv"
	"testing"

	"github.com/google/uuid"
)

// BenchmarkCacheKeyGeneration compares cache key formatting patterns
func BenchmarkCacheKeyGeneration(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"

	b.Run("FmtSprintf", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			_ = fmt.Sprintf("rate:%s:%s", fromCurr, toCurr)
		}
	})

	b.Run("Concat", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			_ = "rate:" + fromCurr + ":" + toCurr
		}
	})
}

// BenchmarkPayloadFormatting compares JSON payload and metadata formatting patterns
func BenchmarkPayloadFormatting(b *testing.B) {
	merchant := "TestMerchant"
	amount := 123.45
	userID := uuid.New()
	newTxID := uuid.New()

	b.Run("FmtSprintfMetadata", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			_ = fmt.Sprintf(`{"provider": "alchemypay", "merchant": "%s", "amount": %f}`, merchant, amount)
		}
	})

	b.Run("ConcatMetadata", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			_ = `{"provider": "alchemypay", "merchant": "` + merchant + `", "amount": ` + strconv.FormatFloat(amount, 'f', -1, 64) + `}`
		}
	})

	b.Run("FmtSprintfOutbox", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			_ = fmt.Sprintf(`{"transaction_id": "%s", "amount": %f, "user_id": "%s", "merchant": "%s"}`, newTxID, amount, userID, merchant)
		}
	})

	b.Run("ConcatOutbox", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			_ = `{"transaction_id": "` + newTxID.String() + `", "amount": ` + strconv.FormatFloat(amount, 'f', -1, 64) + `, "user_id": "` + userID.String() + `", "merchant": "` + merchant + `"}`
		}
	})
}
