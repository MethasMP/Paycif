package main

import (
	"net/http"
	"paysif/internal/usecase"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// KYCHandler handles identity verification requests with the On-Ramp KYC system.
type KYCHandler struct {
	Service *usecase.KYCService
}

// NewKYCHandler creates a new KYCHandler.
func NewKYCHandler(svc *usecase.KYCService) *KYCHandler {
	return &KYCHandler{Service: svc}
}

// RegisterOnRampCustomerRequest matches the JSON input for registration.
type RegisterOnRampCustomerRequest struct {
	FullName       string `json:"full_name" binding:"required,min=3,max=100"`
	PassportNumber string `json:"passport_number" binding:"required,alphanum,min=6,max=20"`
	Nationality    string `json:"nationality" binding:"required,len=2"` // ISO Alpha-2
}

// HandleRegisterOnRampCustomer handles registering the customer with Alchemy Pay's delegated KYC system.
func (h *KYCHandler) HandleRegisterOnRampCustomer(c *gin.Context) {
	var req RegisterOnRampCustomerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID, _ := uuid.Parse(userIDStr.(string))

	dto := usecase.OnRampCustomerDTO{
		UserID:         userID,
		FullName:       req.FullName,
		PassportNumber: req.PassportNumber,
		Nationality:    req.Nationality,
	}

	custID, err := h.Service.RegisterOnRampCustomer(c.Request.Context(), dto)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":             "pending_verification",
		"message":            "Customer registered with On-Ramp KYC system.",
		"onramp_customer_id": custID,
	})
}

// HandleGetOnRampKycStatus retrieves the user's KYC status from the database.
func (h *KYCHandler) HandleGetOnRampKycStatus(c *gin.Context) {
	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID, _ := uuid.Parse(userIDStr.(string))

	status, err := h.Service.GetOnRampKycStatus(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve KYC status"})
		return
	}

	c.JSON(http.StatusOK, status)
}

// HandleOnRampKycWebhook handles status callbacks/webhooks from the On-Ramp provider (e.g. MoonPay/Alchemy Pay KYC success).
func (h *KYCHandler) HandleOnRampKycWebhook(c *gin.Context) {
	// Scaffolding for Webhook: In production, verify signatures and map webhook to user ID
	var payload struct {
		Event          string `json:"event"` // e.g. "kyc.verified", "kyc.failed"
		ExternalUserID string `json:"externalUserId"`
		Status         string `json:"status"` // e.g. "VERIFIED", "REJECTED"
		Tier           string `json:"tier"`   // e.g. "tier1", "tier2"
	}

	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid payload"})
		return
	}

	userID, err := uuid.Parse(payload.ExternalUserID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid external user ID"})
		return
	}

	kycStatus := "PENDING"
	if payload.Status == "VERIFIED" {
		kycStatus = "VERIFIED"
	} else if payload.Status == "REJECTED" {
		kycStatus = "REJECTED"
	}

	if err := h.Service.SyncOnRampKycStatus(c.Request.Context(), userID, kycStatus, payload.Tier); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to sync status"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "success"})
}
