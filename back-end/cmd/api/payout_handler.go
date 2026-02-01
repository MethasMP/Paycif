package main

import (
	"net/http"

	"paysif/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// PayoutHandler handles payout-related API endpoints.
type PayoutHandler struct {
	Service *service.WalletService
}

// NewPayoutHandler creates a new PayoutHandler instance.
func NewPayoutHandler(svc *service.WalletService) *PayoutHandler {
	return &PayoutHandler{Service: svc}
}

// PromptPayPayoutRequest is the JSON body for PromptPay payout.
type PromptPayPayoutRequest struct {
	Amount         int64  `json:"amount" binding:"required,gt=0"` // In satang (minor units)
	PromptPayID    string `json:"promptpay_id" binding:"required"`
	RecipientName  string `json:"recipient_name" binding:"required"`
	IdempotencyKey string `json:"idempotency_key" binding:"required"`
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
