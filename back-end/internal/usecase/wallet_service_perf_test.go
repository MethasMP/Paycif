package usecase

import (
	"fmt"
	"strconv"
	"testing"
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

func BenchmarkPayloadStrSprintf(b *testing.B) {
	newTxID := "uuid-123"
	amount := 123.45
	userID := "user-456"
	merchant := "TestMerchant"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf(`{"transaction_id": "%s", "amount": %f, "user_id": "%s", "merchant": "%s"}`, newTxID, amount, userID, merchant)
	}
}

func BenchmarkPayloadStrManual(b *testing.B) {
	newTxID := "uuid-123"
	amount := 123.45
	userID := "user-456"
	merchant := "TestMerchant"
	for i := 0; i < b.N; i++ {
		_ = `{"transaction_id": "` + newTxID + `", "amount": ` + strconv.FormatFloat(amount, 'f', -1, 64) + `, "user_id": "` + userID + `", "merchant": ` + strconv.Quote(merchant) + `}`
	}
}

func BenchmarkDescriptionSprintf(b *testing.B) {
	recipientName := "John Doe"
	promptPayID := "0812345678"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("PromptPay to %s (%s)", recipientName, promptPayID)
	}
}

func BenchmarkDescriptionConcat(b *testing.B) {
	recipientName := "John Doe"
	promptPayID := "0812345678"
	for i := 0; i < b.N; i++ {
		_ = "PromptPay to " + recipientName + " (" + promptPayID + ")"
	}
}
