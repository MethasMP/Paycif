package main

import (
	"net/http"
	"paysif/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// KYCHandler handles identity verification requests.
type KYCHandler struct {
	Service *service.KYCService
}

// NewKYCHandler creates a new KYCHandler.
func NewKYCHandler(svc *service.KYCService) *KYCHandler {
	return &KYCHandler{Service: svc}
}

// SubmitKYCRequest matches the JSON input.
type SubmitKYCRequest struct {
	FullName       string `json:"full_name" binding:"required"`
	PassportNumber string `json:"passport_number" binding:"required"`
	Nationality    string `json:"nationality" binding:"required"`
}

// HandleSubmitKYC processes the KYC submission.
func (h *KYCHandler) HandleSubmitKYC(c *gin.Context) {
	var req SubmitKYCRequest
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

	dto := service.KYCSubmissionDTO{
		UserID:         userID,
		FullName:       req.FullName,
		PassportNumber: req.PassportNumber,
		Nationality:    req.Nationality,
	}

	if err := h.Service.SubmitKYC(c.Request.Context(), dto); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "success", "message": "KYC submitted securely"})
}

// HandleGetKYC retrieves the user's own KYC data.
func (h *KYCHandler) HandleGetKYC(c *gin.Context) {
	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID, _ := uuid.Parse(userIDStr.(string))

	data, err := h.Service.GetKYC(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "KYC record not found"})
		return
	}

	// Be careful not to expose everything if not needed, but here we return decrypted data to owner.
	c.JSON(http.StatusOK, data)
}
