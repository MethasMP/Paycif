package usecase

import (
	"fmt"
	"strconv"
	"testing"

	"github.com/google/uuid"
)

func BenchmarkGetExchangeRate_CacheKey_Sprintf(b *testing.B) {
	fromCurr := "usd"
	toCurr := "thb"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", fromCurr, toCurr)
	}
}

func BenchmarkGetExchangeRate_CacheKey_Concat(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"
	for i := 0; i < b.N; i++ {
		_ = "rate:" + fromCurr + ":" + toCurr
	}
}

func BenchmarkProcessPayment_JSON_Sprintf(b *testing.B) {
	merchant := "TestMerchant"
	amount := 123.45
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf(`{"provider": "alchemypay", "merchant": "%s", "amount": %f}`, merchant, amount)
	}
}

func BenchmarkProcessPayment_JSON_Concat(b *testing.B) {
	merchant := "TestMerchant"
	amount := 123.45
	for i := 0; i < b.N; i++ {
		_ = `{"provider": "alchemypay", "merchant": "` + merchant + `", "amount": ` + strconv.FormatFloat(amount, 'f', -1, 64) + `}`
	}
}

func BenchmarkPayoutToPromptPay_Description_Sprintf(b *testing.B) {
	recipientName := "John Doe"
	promptPayID := "0812345678"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("PromptPay to %s (%s)", recipientName, promptPayID)
	}
}

func BenchmarkPayoutToPromptPay_Description_Concat(b *testing.B) {
	recipientName := "John Doe"
	promptPayID := "0812345678"
	for i := 0; i < b.N; i++ {
		_ = "PromptPay to " + recipientName + " (" + promptPayID + ")"
	}
}

func BenchmarkProcessPayment_Outbox_Sprintf(b *testing.B) {
	newTxID := uuid.New()
	amount := 123.45
	userID := uuid.New()
	merchant := "TestMerchant"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf(`{"transaction_id": "%s", "amount": %f, "user_id": "%s", "merchant": "%s"}`, newTxID, amount, userID, merchant)
	}
}

func BenchmarkProcessPayment_Outbox_Concat(b *testing.B) {
	newTxID := uuid.New()
	amount := 123.45
	userID := uuid.New()
	merchant := "TestMerchant"
	for i := 0; i < b.N; i++ {
		_ = `{"transaction_id": "` + newTxID.String() + `", "amount": ` + strconv.FormatFloat(amount, 'f', -1, 64) + `, "user_id": "` + userID.String() + `", "merchant": "` + merchant + `"}`
	}
}
