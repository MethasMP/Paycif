package usecase

import (
	"fmt"
	"strconv"
	"testing"

	"github.com/google/uuid"
)

func BenchmarkCacheKeySprintf(b *testing.B) {
	from := "USD"
	to := "THB"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", from, to)
	}
}

func BenchmarkCacheKeyConcat(b *testing.B) {
	from := "USD"
	to := "THB"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + from + ":" + to
	}
}

func BenchmarkMetadataSprintf(b *testing.B) {
	merchant := "TestMerchant"
	amount := 123.45
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf(`{"provider": "alchemypay", "merchant": "%s", "amount": %f}`, merchant, amount)
	}
}

func BenchmarkMetadataConcat(b *testing.B) {
	merchant := "TestMerchant"
	amount := 123.45
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = `{"provider": "alchemypay", "merchant": ` + strconv.Quote(merchant) + `, "amount": ` + strconv.FormatFloat(amount, 'f', -1, 64) + `}`
	}
}

func BenchmarkOutboxPayloadSprintf(b *testing.B) {
	txID := uuid.New().String()
	userID := uuid.New().String()
	amount := 123.45
	merchant := "TestMerchant"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf(`{"transaction_id": "%s", "amount": %f, "user_id": "%s", "merchant": "%s"}`, txID, amount, userID, merchant)
	}
}

func BenchmarkOutboxPayloadConcat(b *testing.B) {
	txID := uuid.New().String()
	userID := uuid.New().String()
	amount := 123.45
	merchant := "TestMerchant"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = `{"transaction_id": "` + txID + `", "amount": ` + strconv.FormatFloat(amount, 'f', -1, 64) + `, "user_id": "` + userID + `", "merchant": ` + strconv.Quote(merchant) + `}`
	}
}

func BenchmarkPayoutDescriptionSprintf(b *testing.B) {
	recipient := "John Doe"
	promptPayID := "0812345678"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("PromptPay to %s (%s)", recipient, promptPayID)
	}
}

func BenchmarkPayoutDescriptionConcat(b *testing.B) {
	recipient := "John Doe"
	promptPayID := "0812345678"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "PromptPay to " + recipient + " (" + promptPayID + ")"
	}
}
