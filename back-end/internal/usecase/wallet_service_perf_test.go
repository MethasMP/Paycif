package usecase_test

import (
	"fmt"
	"strconv"
	"testing"

	"github.com/google/uuid"
)

func BenchmarkGetExchangeRate_CacheKey_Sprintf(b *testing.B) {
	fromCurr := "usd"
	toCurr := "thb"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", fromCurr, toCurr)
	}
}

func BenchmarkProcessPayment_Metadata_Sprintf(b *testing.B) {
	merchant := "Test Merchant"
	amount := 123.45
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf(`{"provider": "alchemypay", "merchant": "%s", "amount": %f}`, merchant, amount)
	}
}

func BenchmarkProcessPayment_Payload_Sprintf(b *testing.B) {
	newTxID := uuid.New().String()
	amount := 123.45
	userID := uuid.New().String()
	merchant := "Test Merchant"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf(`{"transaction_id": "%s", "amount": %f, "user_id": "%s", "merchant": "%s"}`, newTxID, amount, userID, merchant)
	}
}

func BenchmarkPayoutToPromptPay_Description_Sprintf(b *testing.B) {
	recipientName := "John Doe"
	promptPayID := "0812345678"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("PromptPay to %s (%s)", recipientName, promptPayID)
	}
}

// Benchmarks for proposed optimizations

func BenchmarkGetExchangeRate_CacheKey_Concat(b *testing.B) {
	fromCurr := "USD"
	toCurr := "THB"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + fromCurr + ":" + toCurr
	}
}

func BenchmarkProcessPayment_Metadata_Concat(b *testing.B) {
	merchant := "Test Merchant"
	amount := 123.45
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = `{"provider": "alchemypay", "merchant": ` + strconv.Quote(merchant) + `, "amount": ` + strconv.FormatFloat(amount, 'f', 6, 64) + `}`
	}
}

func BenchmarkProcessPayment_Payload_Concat(b *testing.B) {
	newTxID := uuid.New().String()
	amount := 123.45
	userID := uuid.New().String()
	merchant := "Test Merchant"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = `{"transaction_id": "` + newTxID + `", "amount": ` + strconv.FormatFloat(amount, 'f', 6, 64) + `, "user_id": "` + userID + `", "merchant": ` + strconv.Quote(merchant) + `}`
	}
}

func BenchmarkPayoutToPromptPay_Description_Concat(b *testing.B) {
	recipientName := "John Doe"
	promptPayID := "0812345678"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "PromptPay to " + recipientName + " (" + promptPayID + ")"
	}
}
