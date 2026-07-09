package usecase

import (
	"encoding/json"
	"fmt"
	"strconv"
	"testing"

	"github.com/google/uuid"
)

// BenchmarkCacheKeySprintf benchmarks cache key generation using fmt.Sprintf
func BenchmarkCacheKeySprintf(b *testing.B) {
	from := "USD"
	to := "THB"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%s", from, to)
	}
}

// BenchmarkCacheKeyConcat benchmarks cache key generation using string concatenation
func BenchmarkCacheKeyConcat(b *testing.B) {
	from := "USD"
	to := "THB"
	for i := 0; i < b.N; i++ {
		_ = "rate:" + from + ":" + to
	}
}

// BenchmarkMetadataMarshal benchmarks JSON metadata creation using json.Marshal
func BenchmarkMetadataMarshal(b *testing.B) {
	merchant := "TestMerchant"
	amount := 123.45
	for i := 0; i < b.N; i++ {
		m := map[string]interface{}{
			"provider": "alchemypay",
			"merchant": merchant,
			"amount":   amount,
		}
		_, _ = json.Marshal(m)
	}
}

// BenchmarkMetadataManual benchmarks JSON metadata creation using manual string concatenation
func BenchmarkMetadataManual(b *testing.B) {
	merchant := "TestMerchant"
	amount := 123.45
	for i := 0; i < b.N; i++ {
		_ = `{"provider": "alchemypay", "merchant": ` + strconv.Quote(merchant) + `, "amount": ` + strconv.FormatFloat(amount, 'f', -1, 64) + `}`
	}
}

// BenchmarkOutboxPayloadSprintf benchmarks outbox payload creation using fmt.Sprintf
func BenchmarkOutboxPayloadSprintf(b *testing.B) {
	newTxID := uuid.New().String()
	amount := 123.45
	userID := uuid.New().String()
	merchant := "TestMerchant"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf(`{"transaction_id": "%s", "amount": %f, "user_id": "%s", "merchant": "%s"}`, newTxID, amount, userID, merchant)
	}
}

// BenchmarkOutboxPayloadManual benchmarks outbox payload creation using manual string concatenation
func BenchmarkOutboxPayloadManual(b *testing.B) {
	newTxID := uuid.New().String()
	amount := 123.45
	userID := uuid.New().String()
	merchant := "TestMerchant"
	for i := 0; i < b.N; i++ {
		_ = `{"transaction_id": "` + newTxID + `", "amount": ` + strconv.FormatFloat(amount, 'f', -1, 64) + `, "user_id": "` + userID + `", "merchant": ` + strconv.Quote(merchant) + `}`
	}
}

// BenchmarkPromptPayDescriptionSprintf benchmarks PromptPay description creation using fmt.Sprintf
func BenchmarkPromptPayDescriptionSprintf(b *testing.B) {
	recipientName := "John Doe"
	promptPayID := "0812345678"
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("PromptPay to %s (%s)", recipientName, promptPayID)
	}
}

// BenchmarkPromptPayDescriptionConcat benchmarks PromptPay description creation using string concatenation
func BenchmarkPromptPayDescriptionConcat(b *testing.B) {
	recipientName := "John Doe"
	promptPayID := "0812345678"
	for i := 0; i < b.N; i++ {
		_ = "PromptPay to " + recipientName + " (" + promptPayID + ")"
	}
}
