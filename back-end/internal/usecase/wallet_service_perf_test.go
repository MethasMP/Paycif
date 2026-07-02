package usecase

import (
	"encoding/json"
	"strconv"
	"testing"

	"github.com/google/uuid"
)

func BenchmarkJSONConcatSafe(b *testing.B) {
	merchant := "TestMerchant"
	amount := 123.45
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		merchantJSON, _ := json.Marshal(merchant)
		_ = `{"provider": "alchemypay", "merchant": ` + string(merchantJSON) + `, "amount": ` + strconv.FormatFloat(amount, 'f', 6, 64) + `}`
	}
}

func BenchmarkJSONMarshal(b *testing.B) {
	merchant := "TestMerchant"
	amount := 123.45
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		data := map[string]interface{}{
			"provider": "alchemypay",
			"merchant": merchant,
			"amount":   amount,
		}
		_, _ = json.Marshal(data)
	}
}

func BenchmarkOutboxPayloadConcatSafe(b *testing.B) {
	newTxID := uuid.New()
	amount := 123.45
	userID := uuid.New()
	merchant := "TestMerchant"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		merchantJSON, _ := json.Marshal(merchant)
		_ = `{"transaction_id": "` + newTxID.String() + `", "amount": ` + strconv.FormatFloat(amount, 'f', 6, 64) + `, "user_id": "` + userID.String() + `", "merchant": ` + string(merchantJSON) + `}`
	}
}

func BenchmarkOutboxPayloadMarshal(b *testing.B) {
	newTxID := uuid.New()
	amount := 123.45
	userID := uuid.New()
	merchant := "TestMerchant"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		data := map[string]interface{}{
			"transaction_id": newTxID.String(),
			"amount":         amount,
			"user_id":        userID.String(),
			"merchant":       merchant,
		}
		_, _ = json.Marshal(data)
	}
}
