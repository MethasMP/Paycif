package usecase

import (
	"fmt"
	"strconv"
	"testing"

	"github.com/google/uuid"
)

func BenchmarkCacheKeySprintf(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", fromCurr, toCurr)
	}
}

func BenchmarkCacheKeyConcat(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"
	for i := 0; i < b.N; i++ {
		_ = "rate:" + fromCurr + ":" + toCurr
	}
}

func BenchmarkMetadataSprintf(b *testing.B) {
	merchant := "TestMerchant"
	amount := 123.45
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf(`{"provider": "alchemypay", "merchant": "%s", "amount": %f}`, merchant, amount)
	}
}

func BenchmarkMetadataConcat(b *testing.B) {
	merchant := "TestMerchant"
	amount := 123.45
	for i := 0; i < b.N; i++ {
		_ = `{"provider": "alchemypay", "merchant": ` + strconv.Quote(merchant) + `, "amount": ` + strconv.FormatFloat(amount, 'f', -1, 64) + `}`
	}
}

func BenchmarkOutboxPayloadSprintf(b *testing.B) {
	newTxID := uuid.New()
	amount := 123.45
	userID := uuid.New()
	merchant := "TestMerchant"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf(`{"transaction_id": "%s", "amount": %f, "user_id": "%s", "merchant": "%s"}`, newTxID, amount, userID, merchant)
	}
}

func BenchmarkOutboxPayloadConcat(b *testing.B) {
	newTxID := uuid.New()
	amount := 123.45
	userID := uuid.New()
	merchant := "TestMerchant"
	for i := 0; i < b.N; i++ {
		_ = `{"transaction_id": "` + newTxID.String() + `", "amount": ` + strconv.FormatFloat(amount, 'f', -1, 64) + `, "user_id": "` + userID.String() + `", "merchant": ` + strconv.Quote(merchant) + `}`
	}
}
