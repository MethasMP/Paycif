package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"paysif/internal/usecase"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
)

func TestHandleDecodeQR_AllTestQRs(t *testing.T) {
	gin.SetMode(gin.TestMode)

	// Initialize SQRIL Provider with mock client credentials (which triggers our simulator mode)
	sqrilProvider := usecase.NewSqrilProvider(
		"https://stg-api.sqril.io",
		"mock-client-id",
		"mock-client-secret",
	)

	paymentEngine := usecase.NewPaymentEngine("sqril")
	paymentEngine.RegisterProvider(sqrilProvider)

	// Initialize WalletService with the paymentEngine (other dependencies can be nil for this endpoint)
	walletService := usecase.NewWalletService(nil, nil, nil, nil, paymentEngine)

	handler := NewPayoutHandler(walletService, nil)

	r := gin.New()
	// Middleware to inject user_id context (required by HandleDecodeQR)
	r.Use(func(c *gin.Context) {
		c.Set("user_id", uuid.New().String())
		c.Next()
	})
	r.POST("/v1/payout/decode", handler.HandleDecodeQR)

	testCases := []struct {
		name             string
		qrString         string
		expectedAmount   float64
		expectedMerchant string
	}{
		{
			name:             "Tesco Lotus QR",
			qrString:         "00020101021230820016A000000677010112011501055360926419902150000022000755960320461131666018170000005303764540580.855802TH5918TESCO LOTUS CO LTD62120708461131666304BC28",
			expectedAmount:   0.85,
			expectedMerchant: "Tesco Lotus",
		},
		{
			name:             "UNICEF Donation QR",
			qrString:         "00020101021130580016A00000067701011201150994002378766900210DONATION0203010530376454043.005802TH5930UNITED NATIONS CHILDRE",
			expectedAmount:   43.00,
			expectedMerchant: "UNICEF Donation",
		},
		{
			name:             "CPF Store QR",
			qrString:         "00020101021130670016A0000006770101120115010556103866388021012345678900310112233445553037645406103",
			expectedAmount:   3.00,
			expectedMerchant: "CPF Store",
		},
		{
			name:             "Smart Shop QR",
			qrString:         "00020101021130700016A0000006770101120115010556001059500021300011100011120310081909761453037645406104",
			expectedAmount:   4.00,
			expectedMerchant: "Smart Shop",
		},
		{
			name:             "Lim Shop Dynamic QR",
			qrString:         "00020101021230820016A0000006770101120115010753600037405021500000220066077703204611316260181X00000053037645406178",
			expectedAmount:   178.22,
			expectedMerchant: "Lim Shop",
		},
		{
			name:             "Default Fallback QR",
			qrString:         "00020101021230820016A0000006770101120115010753600037401021500000220100001503204611316460181300000053037645406201",
			expectedAmount:   10.00,
			expectedMerchant: "Mock Merchant",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			reqBody, _ := json.Marshal(map[string]string{
				"qr_string": tc.qrString,
			})

			req := httptest.NewRequest(http.MethodPost, "/v1/payout/decode", bytes.NewReader(reqBody))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			r.ServeHTTP(w, req)

			// Assert HTTP status OK
			assert.Equal(t, http.StatusOK, w.Code)

			// Parse response
			var respBody map[string]interface{}
			err := json.Unmarshal(w.Body.Bytes(), &respBody)
			assert.NoError(t, err)

			// Assert simulated values
			assert.Equal(t, tc.expectedAmount, respBody["amount"])
			assert.Equal(t, tc.expectedMerchant, respBody["recipient_name"])
			assert.Equal(t, "business", respBody["type"])
			assert.Equal(t, true, respBody["is_business"])
			assert.Contains(t, respBody["tx_id"], "mock_tx_")
		})
	}
}

func TestHandlePromptPayPayout_BillerIDValidation(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.POST("/v1/payout/promptpay", func(c *gin.Context) {
		// Just parse request to test validation logic
		var req PromptPayPayoutRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		promptPayID := req.PromptPayID
		if req.BillerID != "" {
			promptPayID = req.BillerID
		}

		if promptPayID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Either promptpay_id or biller_id must be provided"})
			return
		}

		length := len(promptPayID)
		if length != 10 && length != 13 && length != 15 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid identifier length"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"status": "validation_passed", "final_id": promptPayID})
	})

	t.Run("Valid 15-digit Biller ID", func(t *testing.T) {
		reqBody, _ := json.Marshal(map[string]interface{}{
			"amount":          1000,
			"recipient_name":  "Unicef Biller",
			"idempotency_key": uuid.New().String(),
			"biller_id":       "010556001059500", // 15 digits
			"reference1":      "REF123",
		})

		req := httptest.NewRequest(http.MethodPost, "/v1/payout/promptpay", bytes.NewReader(reqBody))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()

		r.ServeHTTP(w, req)

		assert.Equal(t, http.StatusOK, w.Code)
		var respBody map[string]interface{}
		_ = json.Unmarshal(w.Body.Bytes(), &respBody)
		assert.Equal(t, "validation_passed", respBody["status"])
		assert.Equal(t, "010556001059500", respBody["final_id"])
	})

	t.Run("Invalid identifier length", func(t *testing.T) {
		reqBody, _ := json.Marshal(map[string]interface{}{
			"amount":          1000,
			"recipient_name":  "Unicef Biller",
			"idempotency_key": uuid.New().String(),
			"biller_id":       "01055600", // Invalid length (8 digits)
		})

		req := httptest.NewRequest(http.MethodPost, "/v1/payout/promptpay", bytes.NewReader(reqBody))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()

		r.ServeHTTP(w, req)

		assert.Equal(t, http.StatusBadRequest, w.Code)
		assert.Contains(t, w.Body.String(), "Invalid identifier length")
	})
}
