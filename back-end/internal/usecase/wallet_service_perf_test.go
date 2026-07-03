package usecase

import (
	"fmt"
	"strconv"
	"testing"

	"github.com/google/uuid"
)

func BenchmarkCacheKeySprintf(b *testing.B) {
	fromCurr, toCurr := "USD", "THB"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", fromCurr, toCurr)
	}
}

func BenchmarkCacheKeyConcat(b *testing.B) {
	fromCurr, toCurr := "USD", "THB"
	for i := 0; i < b.N; i++ {
		_ = "rate:" + fromCurr + ":" + toCurr
	}
}

func BenchmarkAlchemyPayMetadataSprintf(b *testing.B) {
	merchant := "Test Merchant"
	amount := 123.45
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf(`{"provider": "alchemypay", "merchant": "%s", "amount": %f}`, merchant, amount)
	}
}

func BenchmarkAlchemyPayMetadataQuote(b *testing.B) {
	merchant := "Test Merchant"
	amount := 123.45
	for i := 0; i < b.N; i++ {
		_ = `{"provider": "alchemypay", "merchant": ` + strconv.Quote(merchant) + `, "amount": ` + strconv.FormatFloat(amount, 'f', 6, 64) + `}`
	}
}

func BenchmarkOutboxPayloadSprintf(b *testing.B) {
	newTxID := uuid.New().String()
	amount := 123.45
	userID := uuid.New().String()
	merchant := "Test Merchant"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf(`{"transaction_id": "%s", "amount": %f, "user_id": "%s", "merchant": "%s"}`, newTxID, amount, userID, merchant)
	}
}

func BenchmarkOutboxPayloadQuote(b *testing.B) {
	newTxID := uuid.New().String()
	amount := 123.45
	userID := uuid.New().String()
	merchant := "Test Merchant"
	for i := 0; i < b.N; i++ {
		_ = `{"transaction_id": "` + newTxID + `", "amount": ` + strconv.FormatFloat(amount, 'f', 6, 64) + `, "user_id": "` + userID + `", "merchant": ` + strconv.Quote(merchant) + `}`
	}
}

func BenchmarkPromptPayDescriptionSprintf(b *testing.B) {
	recipientName := "John Doe"
	promptPayID := "0812345678"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("PromptPay to %s (%s)", recipientName, promptPayID)
	}
}

func BenchmarkPromptPayDescriptionConcat(b *testing.B) {
	recipientName := "John Doe"
	promptPayID := "0812345678"
	for i := 0; i < b.N; i++ {
		_ = "PromptPay to " + recipientName + " (" + promptPayID + ")"
	}
}
