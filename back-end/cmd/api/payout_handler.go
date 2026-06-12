package main

import (
	"net/http"
	"strings"

	"paysif/internal/usecase"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

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
	Amount         int64  `json:"amount" binding:"required,gt=0"`                // In satang (minor units)
	PromptPayID    string `json:"promptpay_id" binding:"required,min=10,max=13"` // Mobile or ID
	RecipientName  string `json:"recipient_name" binding:"required,min=3,max=100"`
	IdempotencyKey string `json:"idempotency_key" binding:"required,uuid"`
	SqrilTxID      string `json:"sqril_tx_id"`
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

	// Verify Signature: The payload being signed is the IdempotencyKey
	isValid, err := h.SignatureService.VerifySignature(c.Request.Context(), publicKey, signature, req.IdempotencyKey)
	if err != nil || !isValid {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Request integrity check failed"})
		return
	}

	// 3. Call Service
	payoutReq := usecase.PayoutRequest{
		UserID:         userID,
		Amount:         req.Amount,
		PromptPayID:    req.PromptPayID,
		RecipientName:  req.RecipientName,
		IdempotencyKey: req.IdempotencyKey,
		SqrilTxID:      req.SqrilTxID,
	}

	resp, err := h.Service.PayoutToPromptPay(c.Request.Context(), payoutReq)
	if err != nil {
		// Differentiate error types and return concise UX messages
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

	// 4. Return Success
	c.JSON(http.StatusOK, resp)
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

	if !resp.IsBusiness {
		c.JSON(http.StatusBadRequest, gin.H{
			"error_code": "PERSONAL_QR_NOT_SUPPORTED",
			"header":     "Personal QR Not Supported",
			"message":    "We currently only support payments to registered Merchant QRs due to regulatory requirements.",
		})
		return
	}

	c.JSON(http.StatusOK, resp)
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
