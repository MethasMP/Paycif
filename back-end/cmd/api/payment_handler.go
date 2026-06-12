package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"

	"paysif/internal/usecase"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type PaymentHandler struct {
	Service *usecase.WalletService
}

func NewPaymentHandler(svc *usecase.WalletService) *PaymentHandler {
	return &PaymentHandler{Service: svc}
}

type CreatePayoutIntentRequest struct {
	Amount        int64  `json:"amount" binding:"required,gt=0"` // In satangs/cents
	PromptPayID   string `json:"promptpay_id" binding:"required"`
	RecipientName string `json:"recipient_name" binding:"required"`
	SqrilTxID     string `json:"sqril_tx_id" binding:"required"`
}

// HandleCreateIntent creates an Alchemy Pay order intent in repository.
func (h *PaymentHandler) HandleCreateIntent(c *gin.Context) {
	var req CreatePayoutIntentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	userIDStr := c.GetString("user_id")
	if userIDStr == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User unauthorized"})
		return
	}
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID"})
		return
	}

	// 🛡️ Pre-flight Check: Validate quote validity via active provider
	prov, ok := h.Service.PaymentEngine.GetProvider("sqril")
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "SQRIL provider not registered"})
		return
	}
	sqril, ok := prov.(*usecase.SqrilProvider)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid SQRIL provider configuration"})
		return
	}

	// Check if quote exists and is valid on SQRIL (pre-flight validation before holding funds)
	_, err = sqril.GetQuotation(c.Request.Context(), req.SqrilTxID, "cust_paycif_"+userID.String(), req.Amount)
	if err != nil {
		errStr := strings.ToLower(err.Error())
		if strings.Contains(errStr, "expire") || strings.Contains(errStr, "timeout") {
			c.JSON(http.StatusBadRequest, gin.H{
				"error_code": "QR_EXPIRED",
				"header":     "QR Code Expired",
				"message":    "Please ask the merchant for a new QR code.",
			})
		} else {
			c.JSON(http.StatusBadRequest, gin.H{
				"error_code": "INVALID_QR",
				"header":     "Invalid QR Code",
				"message":    "We only support Thai PromptPay. Please check the code.",
			})
		}
		return
	}



	// Create a new PayoutIntent mapping
	intentID := uuid.New()
	intent := usecase.PayoutIntent{
		ID:            intentID,
		UserID:        userID,
		Amount:        req.Amount,
		PromptPayID:   req.PromptPayID,
		RecipientName: req.RecipientName,
		SqrilTxID:     req.SqrilTxID,
		Status:        "PENDING",
	}

	err = h.Service.CreatePayoutIntent(c.Request.Context(), intent)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create payment intent: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"intent_id":   intentID.String(),
		"merchant_no": intentID.String(), // mapping to Alchemy Pay merchantOrderNo
		"amount":      req.Amount,
	})
}

// AlchemyPayWebhookPayload matches Alchemy Pay callback schema
type AlchemyPayWebhookPayload struct {
	OrderNo         string `json:"orderNo"`
	MerchantOrderNo string `json:"merchantOrderNo"`
	Status          string `json:"status"` // FINISHED, FAILED, etc.
	Amount          string `json:"amount"`
	Currency        string `json:"currency"`
	CryptoAmount    string `json:"cryptoAmount"`
	Crypto          string `json:"crypto"`
	UserId          string `json:"userId"`
	Signature       string `json:"signature"`
}

// HandleWebhook processes payments and executes payouts atomically upon card authorization success.
func (h *PaymentHandler) HandleWebhook(c *gin.Context) {
	const MaxBodyBytes = int64(65536)
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, MaxBodyBytes)
	payload, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Error reading request body"})
		return
	}

	// Verify Alchemy Pay signature
	signature := c.GetHeader("X-Alchemy-Signature")
	secret := os.Getenv("ALCHEMY_PAY_SECRET_KEY")
	if secret != "" && !verifyAlchemySignature(payload, signature, secret) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid Alchemy Pay signature"})
		return
	}

	var data AlchemyPayWebhookPayload
	if err := json.Unmarshal(payload, &data); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Error parsing webhook JSON"})
		return
	}

	log.Printf("Received Alchemy Pay webhook for order: %s, status: %s", data.MerchantOrderNo, data.Status)

	if data.Status == "FINISHED" {
		intentUUID, err := uuid.Parse(data.MerchantOrderNo)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid merchant order number format"})
			return
		}

		// 1. Fetch PayoutIntent
		intent, err := h.Service.GetPayoutIntent(c.Request.Context(), intentUUID)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Payout intent not found"})
			return
		}

		if intent.Status == "COMPLETED" {
			c.JSON(http.StatusOK, gin.H{"status": "already_processed"})
			return
		}

		// 2. Record payment in ledger (Credit USDC to tourist)
		merchantDescription := fmt.Sprintf("Alchemy Pay: %s %s", data.Amount, data.Currency)
		err = h.Service.ProcessPayment(c.Request.Context(), intent.UserID, float64(intent.Amount)/100.0, merchantDescription, data.OrderNo)
		if err != nil {
			log.Printf("⚠️ Failed to process payment record for intent %s: %v", intent.ID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal ledger processing error"})
			return
		}

		// 3. Trigger SQRIL payout instantly (Debit ledger + execute SQRIL API)
		payoutReq := usecase.PayoutRequest{
			UserID:         intent.UserID,
			Amount:         intent.Amount,
			PromptPayID:    intent.PromptPayID,
			RecipientName:  intent.RecipientName,
			IdempotencyKey: intent.ID.String(), // Use PayoutIntent ID as idempotency key
			SqrilTxID:      intent.SqrilTxID,
		}

		payoutResp, err := h.Service.PayoutToPromptPay(c.Request.Context(), payoutReq)
		if err != nil {
			log.Printf("⚠️ Instant payout failed for intent %s (will be retried by outbox worker): %v", intent.ID, err)
			// Still return 200 to Alchemy Pay because card payment is complete and outbox worker will retry the payout
			_ = h.Service.UpdatePayoutIntentStatus(c.Request.Context(), intent.ID, "PAYMENT_SUCCESS_PAYOUT_PENDING")
			c.JSON(http.StatusOK, gin.H{"status": "payout_pending_retry", "error": err.Error()})
			return
		}

		_ = h.Service.UpdatePayoutIntentStatus(c.Request.Context(), intent.ID, "COMPLETED")
		log.Printf("✅ Instant payout executed successfully for intent %s, status: %s", intent.ID, payoutResp.Status)
	}

	c.JSON(http.StatusOK, gin.H{"status": "success"})
}

func verifyAlchemySignature(payload []byte, signature string, secret string) bool {
	h := hmac.New(sha256.New, []byte(secret))
	h.Write(payload)
	expectedSignature := hex.EncodeToString(h.Sum(nil))
	return hmac.Equal([]byte(signature), []byte(expectedSignature))
}
