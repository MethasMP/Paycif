package usecase_test

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"paysif/internal/usecase"

	"github.com/stretchr/testify/assert"
)

func TestSqrilProvider_DecodeQR(t *testing.T) {
	// 1. Setup mock SQRIL API server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, "/decodeQr", r.URL.Path)
		assert.Equal(t, "POST", r.Method)
		assert.Equal(t, "application/json", r.Header.Get("Content-Type"))

		// Verify basic auth header
		authHeader := r.Header.Get("Authorization")
		assert.NotEmpty(t, authHeader)

		// Parse body
		var body map[string]interface{}
		err := json.NewDecoder(r.Body).Decode(&body)
		assert.NoError(t, err)
		assert.Equal(t, "raw_qr_payload", body["qr_string"])
		assert.Equal(t, "cust_123", body["customer_id"])

		// Return simulated response
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{
			"is_dynamic": false,
			"is_business": true,
			"amount": 25000,
			"merchant": "TESCO LOTUS",
			"country": "TH",
			"tx_id": "tx_sqril_123456",
			"currency": "THB",
			"amount_usd": 6.84,
			"fee": 0.1,
			"percentage_fee": 0.1,
			"fixed_fee": 0.0,
			"deposit_address": "0xABCDEF1234567890"
		}`))
	}))
	defer server.Close()

	// 2. Initialize provider (passing nil as DB)
	provider := usecase.NewSqrilProvider(server.URL, "client_id", "client_secret", nil)

	// 3. Invoke DecodeQR
	resp, err := provider.DecodeQR(context.Background(), "raw_qr_payload", "cust_123", "partner_tx_999")
	assert.NoError(t, err)
	assert.NotNil(t, resp)
	assert.Equal(t, "tx_sqril_123456", resp.TxID)
	assert.Equal(t, "TESCO LOTUS", resp.Merchant)
	assert.Equal(t, int64(25000), resp.Amount)
	assert.Equal(t, false, resp.IsDynamic)
	assert.Equal(t, "0xABCDEF1234567890", resp.DepositAddress)
}

func BenchmarkGetTransactionURL(b *testing.B) {
	baseURL := "https://api.sqril.com/v1"
	txID := "tx_sqril_123456789"

	b.Run("fmt.Sprintf", func(b *testing.B) {
		b.ReportAllocs()
		for i := 0; i < b.N; i++ {
			_ = usecase_test_sprintf(baseURL, txID)
		}
	})

	b.Run("string concatenation", func(b *testing.B) {
		b.ReportAllocs()
		for i := 0; i < b.N; i++ {
			_ = baseURL + "/getTransaction?transaction_id=" + txID
		}
	})
}

func usecase_test_sprintf(baseURL, transactionID string) string {
	return fmt.Sprintf("%s/getTransaction?transaction_id=%s", baseURL, transactionID)
}

func TestSqrilProvider_GetQuotation(t *testing.T) {
	// 1. Setup mock SQRIL API server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, "/getQuotation", r.URL.Path)
		assert.Equal(t, "POST", r.Method)

		var body map[string]interface{}
		err := json.NewDecoder(r.Body).Decode(&body)
		assert.NoError(t, err)
		assert.Equal(t, "tx_sqril_123456", body["tx_id"])
		assert.Equal(t, "cust_123", body["customer_id"])

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{
			"tx_id": "tx_sqril_123456",
			"amount": 25000,
			"currency": "THB",
			"exchange_rate": 0.02739726,
			"amount_usd": 6.85,
			"fee": 0.10,
			"percentage_fee": 0.10,
			"fixed_fee": 0.00,
			"expires_at": "2026-06-11T15:30:00Z",
			"deposit_address": "0xABCDEF1234567890"
		}`))
	}))
	defer server.Close()

	// 2. Initialize provider (passing nil as DB)
	provider := usecase.NewSqrilProvider(server.URL, "client_id", "client_secret", nil)

	// 3. Invoke GetQuotation
	resp, err := provider.GetQuotation(context.Background(), "tx_sqril_123456", "cust_123", 25000)
	assert.NoError(t, err)
	assert.NotNil(t, resp)
	assert.Equal(t, "tx_sqril_123456", resp.TxID)
	assert.Equal(t, 0.02739726, resp.ExchangeRate)
	assert.Equal(t, 6.85, resp.AmountUSD)
	assert.Equal(t, "0xABCDEF1234567890", resp.DepositAddress)
}
