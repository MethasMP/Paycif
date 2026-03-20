package main

import (
	"net/http"

	"paysif/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// PayoutHandler handles payout-related API endpoints.
type PayoutHandler struct {
	Service          *service.WalletService
	SignatureService *service.SignatureService
}

// NewPayoutHandler creates a new PayoutHandler instance.
func NewPayoutHandler(svc *service.WalletService, sigSvc *service.SignatureService) *PayoutHandler {
	return &PayoutHandler{
		Service:          svc,
		SignatureService: sigSvc,
	}
}

// PromptPayPayoutRequest is the JSON body for PromptPay payout.
type PromptPayPayoutRequest struct {
	Amount         int64  `json:"amount" binding:"required,gt=0"` // In satang (minor units)
	PromptPayID    string `json:"promptpay_id" binding:"required,min=10,max=13"` // Mobile or ID
	RecipientName  string `json:"recipient_name" binding:"required,min=3,max=100"`
	IdempotencyKey string `json:"idempotency_key" binding:"required,uuid"`
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
	payoutReq := service.PayoutRequest{
		UserID:         userID,
		Amount:         req.Amount,
		PromptPayID:    req.PromptPayID,
		RecipientName:  req.RecipientName,
		IdempotencyKey: req.IdempotencyKey,
	}

	resp, err := h.Service.PayoutToPromptPay(c.Request.Context(), payoutReq)
	if err != nil {
		// Differentiate error types
		errMsg := err.Error()
		if errMsg == "insufficient balance" {
			c.JSON(http.StatusPaymentRequired, gin.H{"error": errMsg})
			return
		}
		if errMsg == "wallet not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": errMsg})
			return
		}
		// Generic error
		c.JSON(http.StatusInternalServerError, gin.H{"error": errMsg})
		return
	}

	// 4. Return Success
	c.JSON(http.StatusOK, resp)
}
