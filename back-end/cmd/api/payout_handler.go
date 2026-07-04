package main

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"

	"paysif/internal/usecase"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

var numericRegex = regexp.MustCompile("^[0-9]+$")

// ComputePayloadHash constructs a SHA-256 hash of the payout request parameters for integrity checks.
func ComputePayloadHash(req PromptPayPayoutRequest) string {
	h := sha256.New()
	h.Write([]byte(strconv.FormatInt(req.Amount, 10)))
	h.Write([]byte{':'})
	h.Write([]byte(req.PromptPayID))
	h.Write([]byte{':'})
	h.Write([]byte(req.RecipientName))
	h.Write([]byte{':'})
	h.Write([]byte(req.IdempotencyKey))
	h.Write([]byte{':'})
	h.Write([]byte(req.SqrilTxID))
	h.Write([]byte{':'})
	h.Write([]byte(req.BillerID))
	h.Write([]byte{':'})
	h.Write([]byte(req.Reference1))
	h.Write([]byte{':'})
	h.Write([]byte(req.Reference2))
	return hex.EncodeToString(h.Sum(nil))
}

// PayoutHandler handles payout-related API endpoints.
type PayoutHandler struct {
	Service          *usecase.WalletService
	SignatureService *usecase.SignatureService
}

// NewPayoutHandler creates a new PayoutHandler instance.
func NewPayoutHandler(svc *usecase.WalletService, sigSvc *usecase.SignatureService) *PayoutHandler {
	return &PayoutHandler{
		Service:          svc,
		SignatureService: sigSvc,
	}
}

// PromptPayPayoutRequest is the JSON body for PromptPay payout.
type PromptPayPayoutRequest struct {
	Amount         int64  `json:"amount" binding:"required,gt=0"` // In satang (minor units)
	PromptPayID    string `json:"promptpay_id"`                   // Mobile or ID, optional if biller_id is used
	RecipientName  string `json:"recipient_name" binding:"required,min=3,max=100"`
	IdempotencyKey string `json:"idempotency_key" binding:"required,uuid"`
	SqrilTxID      string `json:"sqril_tx_id"`
	BillerID       string `json:"biller_id"` // Optional Biller ID (15 digits)
	Reference1     string `json:"reference1"`
	Reference2     string `json:"reference2"`
}

// HandlePromptPayPayout processes a payout to a PromptPay account.
func (h *PayoutHandler) HandlePromptPayPayout(c *gin.Context) {
	// 1. Parse Request
	var req PromptPayPayoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 2. Get User ID from Auth Context
	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User unauthorized"})
		return
	}
	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID in token"})
		return
	}

	// 🛡️ SECURITY: Hardened Device Signature Verification
	deviceId := c.GetHeader("X-Device-Id")
	signature := c.GetHeader("X-Device-Signature")

	if deviceId == "" || signature == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Device authorization missing"})
		return
	}

	// Fetch Public Key for this device and user
	publicKey, err := h.SignatureService.GetDevicePublicKey(c.Request.Context(), userID, deviceId)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	// Verify Signature: The payload being signed is the SHA-256 hash of the payload parameters
	payloadHash := ComputePayloadHash(req)
	isValid, err := h.SignatureService.VerifySignature(c.Request.Context(), publicKey, signature, payloadHash)
	if err != nil || !isValid {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Request integrity check failed"})
		return
	}

	// 3. Call Service
	promptPayID := req.PromptPayID
	if req.BillerID != "" {
		promptPayID = req.BillerID
	}

	if promptPayID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Either promptpay_id or biller_id must be provided"})
		return
	}

	// Dynamic validation: mobile (10 digits), national ID/Tax ID (13 digits), or Biller ID (15 digits)
	length := len(promptPayID)
	if length != 10 && length != 13 && length != 15 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid identifier length. Must be 10, 13, or 15 digits."})
		return
	}

	if !numericRegex.MatchString(promptPayID) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid identifier format. Must contain only numeric characters."})
		return
	}

	payoutReq := usecase.PayoutRequest{
		UserID:         userID,
		Amount:         req.Amount,
		PromptPayID:    promptPayID,
		RecipientName:  req.RecipientName,
		IdempotencyKey: req.IdempotencyKey,
		SqrilTxID:      req.SqrilTxID,
	}

	resp, err := h.Service.PayoutToPromptPay(c.Request.Context(), payoutReq)
	if err != nil {
		_ = c.Error(err)
		if errors.Is(err, usecase.ErrLimitExceeded) {
			c.JSON(http.StatusBadRequest, gin.H{
				"error_code": "LIMIT_EXCEEDED",
				"header":     "Limit Exceeded",
				"message":    "This amount exceeds your current KYC verification limit. Please verify your identity further or try a smaller amount.",
			})
			return
		}

		if errors.Is(err, usecase.ErrNetworkUnavailable) {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"error_code": "NETWORK_DOWN",
				"header":     "Payment Failed",
				"message":    "The Thai payment network is currently down. No charge was made. Please try again later.",
			})
			return
		}

		if errors.Is(err, usecase.ErrMerchantUnavailable) {
			c.JSON(http.StatusBadGateway, gin.H{
				"error_code": "MERCHANT_ERROR",
				"header":     "Cannot Pay Merchant",
				"message":    "The merchant's account cannot receive funds right now. No charge was made.",
			})
			return
		}

		// Fallback error parsing if it is a wrapped or other error
		errMsg := strings.ToLower(err.Error())

		if strings.Contains(errMsg, "limit") || strings.Contains(errMsg, "exceed") {
			c.JSON(http.StatusBadRequest, gin.H{
				"error_code": "LIMIT_EXCEEDED",
				"header":     "Limit Exceeded",
				"message":    "This amount exceeds your current KYC verification limit. Please verify your identity further or try a smaller amount.",
			})
			return
		}

		if strings.Contains(errMsg, "unavailable") || strings.Contains(errMsg, "circuit breaker") || strings.Contains(errMsg, "timeout") {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"error_code": "NETWORK_DOWN",
				"header":     "Payment Failed",
				"message":    "The Thai payment network is currently down. No charge was made. Please try again later.",
			})
			return
		}

		// Generic Merchant/Account Error
		c.JSON(http.StatusBadGateway, gin.H{
			"error_code": "MERCHANT_ERROR",
			"header":     "Cannot Pay Merchant",
			"message":    "The merchant's account cannot receive funds right now. No charge was made.",
		})
		return
	}

	// 4. Return Success (202 Accepted for async execution)
	c.JSON(http.StatusAccepted, resp)
}

// DecodeQRRequest is the JSON body for Decode QR endpoint
type DecodeQRRequest struct {
	QRString string `json:"qr_string" binding:"required"`
}

// HandleDecodeQR handles SQRIL QR decoding
func (h *PayoutHandler) HandleDecodeQR(c *gin.Context) {
	var req DecodeQRRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User unauthorized"})
		return
	}
	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID"})
		return
	}

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

	partnerTxID := "partner_tx_" + uuid.New().String()
	resp, err := sqril.DecodeQR(c.Request.Context(), req.QRString, "cust_paycif_"+userID.String(), partnerTxID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error_code": "INVALID_QR",
			"header":     "Invalid QR Code",
			"message":    "We only support Thai PromptPay. Please check the code.",
		})
		return
	}

	// 🔄 Map SQRIL internal response to match Frontend Model (decoded_qr.dart)
	amountMajor := float64(resp.Amount) / 100.0
	typeOfQr := "business"
	if !resp.IsBusiness {
		typeOfQr = "personal"
	}

	c.JSON(http.StatusOK, gin.H{
		"tx_id":          resp.TxID,
		"amount":         amountMajor,
		"recipient_name": resp.Merchant,
		"type":           typeOfQr,
		"is_business":    resp.IsBusiness,
	})
}

// GetQuotationRequest is the JSON body for Get Quotation endpoint
type GetQuotationRequest struct {
	TxID   string `json:"tx_id" binding:"required"`
	Amount int64  `json:"amount"` // Optional, in satangs
}

// HandleGetQuotation handles SQRIL quotation retrieval
func (h *PayoutHandler) HandleGetQuotation(c *gin.Context) {
	var req GetQuotationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User unauthorized"})
		return
	}
	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID"})
		return
	}

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

	resp, err := sqril.GetQuotation(c.Request.Context(), req.TxID, "cust_paycif_"+userID.String(), req.Amount)
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

	c.JSON(http.StatusOK, resp)
}

// SqrilWebhookPayload matches SQRIL webhook payload
type SqrilWebhookPayload struct {
	TxID         string                 `json:"tx_id"`
	Status       string                 `json:"status"` // SUCCESS or FAILED
	ErrorMessage string                 `json:"error_message,omitempty"`
	Sender       map[string]interface{} `json:"sender,omitempty"`
	Recipient    map[string]interface{} `json:"recipient,omitempty"`
}

// HandleSqrilWebhook receives SQRIL payment final statuses and updates database/refunds
func (h *PayoutHandler) HandleSqrilWebhook(c *gin.Context) {
	const maxBody = int64(65536)
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBody)
	payload, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Error reading request body"})
		return
	}

	var data SqrilWebhookPayload
	if err := json.Unmarshal(payload, &data); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Error parsing webhook JSON"})
		return
	}

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

	// Verify HMAC-SHA256 signature
	signature := c.GetHeader("X-SQRIL-Signature")
	webhookSecret := os.Getenv("SQRIL_WEBHOOK_SECRET")

	// If it's a real integration (not mock client)
	if sqril.ClientID != "mock-client-id" {
		if webhookSecret == "" {
			log.Printf("CRITICAL SECURITY ERROR: SQRIL_WEBHOOK_SECRET environment variable is not configured.")
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Webhook signing secret is not configured"})
			return
		}
		if !sqril.VerifyWebhookSignature(payload, signature, webhookSecret) {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid signature"})
			return
		}
	} else {
		// Mock environment fallback
		if webhookSecret == "" {
			webhookSecret = "mock-webhook-secret"
		}
		if signature != "" && !sqril.VerifyWebhookSignature(payload, signature, webhookSecret) {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid signature"})
			return
		}
	}

	log.Printf("SQRIL Webhook status: tx_id=%s status=%s", data.TxID, data.Status)

	if strings.TrimSpace(data.TxID) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "tx_id is required"})
		return
	}

	// Fetch transaction from DB using sqril_tx_id
	var txID uuid.UUID
	var userUUID uuid.UUID
	var amount int64
	var currentStatus string
	var senderFullName string

	db := h.Service.DB

	// Start database transaction to update status and handle refund if failed
	tx, err := db.BeginTx(c.Request.Context(), &sql.TxOptions{Isolation: sql.LevelReadCommitted})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start database transaction"})
		return
	}
	defer tx.Rollback()

	err = tx.QueryRowContext(c.Request.Context(), `
		SELECT id, profile_id, amount, status 
		FROM transactions 
		WHERE provider_metadata->>'external_id' = $1 FOR UPDATE
	`, data.TxID).Scan(&txID, &userUUID, &amount, &currentStatus)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Transaction not found for this SQRIL tx_id"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}

	if currentStatus == "SUCCESS" || currentStatus == "FAILED" {
		c.JSON(http.StatusOK, gin.H{"received": true, "message": "Already processed"})
		return
	}

	settlementStatus := "PENDING"
	newStatus := currentStatus
	if data.Status == "SUCCESS" {
		settlementStatus = "SETTLED"
		newStatus = "SUCCESS"
	} else if data.Status == "FAILED" {
		settlementStatus = "FAILED"
		newStatus = "FAILED"
	}

	_, err = tx.ExecContext(c.Request.Context(), `
		UPDATE transactions
		SET settlement_status = $1::settlement_status_enum,
		    status = $2
		WHERE id = $3
	`, settlementStatus, newStatus, txID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update transaction"})
		return
	}

	if data.Status == "FAILED" {
		log.Printf("⚠️ SQRIL Webhook FAILED. Performing refund for transaction %s.", txID)
		// Lock profile row
		err = tx.QueryRowContext(c.Request.Context(), "SELECT full_name FROM profiles WHERE id = $1 FOR UPDATE", userUUID).Scan(&senderFullName)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to lock profile for refund"})
			return
		}

		// Calculate current balance (locking is handled by the profiles row lock above)
		var balanceBeforeRefund int64
		err = tx.QueryRowContext(c.Request.Context(), "SELECT COALESCE(SUM(amount), 0) FROM ledger_entries WHERE profile_id = $1", userUUID).Scan(&balanceBeforeRefund)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to calculate balance for refund"})
			return
		}

		// Insert refund ledger entry (credit)
		_, err = tx.ExecContext(c.Request.Context(), `
			INSERT INTO ledger_entries (id, transaction_id, profile_id, amount, balance_after, base_currency_amount, home_currency_amount)
			VALUES ($1, $2, $3, $4, $5, $4, $4)
		`, uuid.New(), txID, userUUID, amount, balanceBeforeRefund+amount)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create refund entry"})
			return
		}
	}

	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit database transaction"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"received": true, "message": "Webhook processed successfully"})
}
