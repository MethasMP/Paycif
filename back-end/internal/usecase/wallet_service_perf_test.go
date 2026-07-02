package usecase

import (
	"strconv"
	"testing"

	"github.com/google/uuid"
)

func BenchmarkCacheKeyConcat(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + fromCurr + ":" + toCurr
	}
}

func BenchmarkJSONConcat(b *testing.B) {
	merchant := "TestMerchant"
	amount := 123.45
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = `{"provider": "alchemypay", "merchant": ` + strconv.Quote(merchant) + `, "amount": ` + strconv.FormatFloat(amount, 'f', 6, 64) + `}`
	}
}

func BenchmarkOutboxPayloadConcat(b *testing.B) {
	newTxID := uuid.New()
	amount := 123.45
	userID := uuid.New()
	merchant := "TestMerchant"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = `{"transaction_id": "` + newTxID.String() + `", "amount": ` + strconv.FormatFloat(amount, 'f', 6, 64) + `, "user_id": "` + userID.String() + `", "merchant": ` + strconv.Quote(merchant) + `}`
	}
}
