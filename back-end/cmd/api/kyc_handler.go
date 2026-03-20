package main

import (
	"encoding/json"
	"io"
	"net/http"
	"paysif/internal/service"
	"paysif/pkg/nfc" // New import for NFC crypto module
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// KYCHandler handles identity verification requests.
type KYCHandler struct {
	Service       *service.KYCService
	SumsubService *service.SumsubService
}

// NewKYCHandler creates a new KYCHandler.
func NewKYCHandler(svc *service.KYCService, sumsub *service.SumsubService) *KYCHandler {
	return &KYCHandler{Service: svc, SumsubService: sumsub}
}

// SubmitKYCRequest matches the JSON input.
type SubmitKYCRequest struct {
	FullName       string `json:"full_name" binding:"required,min=3,max=100"`
	PassportNumber string `json:"passport_number" binding:"required,alphanum,min=6,max=20"`
	Nationality    string `json:"nationality" binding:"required,len=2"` // ISO Alpha-2
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

// HandleSubmitNfcPassport processes the highly secure, cryptographically backed NFC Passport payload.
func (h *KYCHandler) HandleSubmitNfcPassport(c *gin.Context) {
	var payload nfc.NfcPassportPayload
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid NFC payload format"})
		return
	}

	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID, _ := uuid.Parse(userIDStr.(string))

	// 1. Cryptographically verify the NFC chip signature (Passive Authentication)
	identity, err := nfc.VerifyPassportNfcSignature(payload)
	if err != nil {
		// Log detailed error internally, return generic error to client
		c.JSON(http.StatusUnprocessableEntity, gin.H{"error": "Passport authentication failed. Chip data may be altered."})
		return
	}

	// 2. Map verified identity back to our KYC service (which encrypts and saves securely)
	dto := service.KYCSubmissionDTO{
		UserID:         userID,
		FullName:       identity.FirstName + " " + identity.LastName,
		PassportNumber: identity.DocumentNumber,
		Nationality:    identity.Nationality,
		// Pass raw groups for cryptographic binding audit
		DG1: payload.DG1,
		DG2: payload.DG2,
		SOD: payload.SOD,
	}

	if err := h.Service.SubmitKYC(c.Request.Context(), dto); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save verified identity"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":     "verified",
		"message":    "NFC Passport Signature verified and identity secured.",
		"name":       dto.FullName,
		"session_id": uuid.New().String(), // Send session ID for biometric phase
	})
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

	c.JSON(http.StatusOK, data)
}

// SubmitSelfieRequest handles the selfie image submission.
type SubmitSelfieRequest struct {
	SelfieBase64 string `json:"selfie_base64" binding:"required"`
	SessionID    string `json:"session_id" binding:"required"`
}

// HandleSubmitSelfie processes the selfie for biometric matching against verified NFC data.
func (h *KYCHandler) HandleSubmitSelfie(c *gin.Context) {
	var req SubmitSelfieRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid selfie data"})
		return
	}

	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID, _ := uuid.Parse(userIDStr.(string))

	// Call the service method which performs matching against stored DG2
	if err := h.Service.VerifySelfie(c.Request.Context(), userID, req.SelfieBase64, req.SessionID); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":  "success",
		"message": "Identity verified with 1:1 Biometric matching.",
	})
}

// HandleGetSumsubToken generates a new SDK access token for the user.
func (h *KYCHandler) HandleGetSumsubToken(c *gin.Context) {
	userIDStr, _ := c.Get("user_id")
	userID, _ := uuid.Parse(userIDStr.(string))

	// Create Applicant if not exists
	applicantID, err := h.SumsubService.CreateApplicant(userID.String(), "basic-kyc-level")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create Sumsub applicant: " + err.Error()})
		return
	}

	// Update DB with Applicant ID
	if err := h.Service.UpdateSumsubApplicantID(c.Request.Context(), userID, applicantID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update record"})
		return
	}

	// Generate SDK Token
	token, err := h.SumsubService.GenerateAccessToken(userID.String(), "basic-kyc-level")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate Sumsub token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"token":      token,
		"expires_at": time.Now().Add(30 * time.Minute).Unix(),
	})
}

// HandleSumsubWebhook handles status updates from Sumsub.
func (h *KYCHandler) HandleSumsubWebhook(c *gin.Context) {
	payload, _ := io.ReadAll(c.Request.Body)
	signature := c.GetHeader("X-App-Access-Sig")

	if !h.SumsubService.VerifyWebhookSignature(payload, signature) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid signature"})
		return
	}

	var event struct {
		Type           string `json:"type"`
		ExternalUserID string `json:"externalUserId"`
		ReviewResult   struct {
			ReviewAnswer string `json:"reviewAnswer"`
		} `json:"reviewResult"`
	}

	if err := json.Unmarshal(payload, &event); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid JSON"})
		return
	}

	if event.Type == "applicantReviewed" {
		userID, _ := uuid.Parse(event.ExternalUserID)
		status := "REJECTED"
		tier := "tier0"

		if event.ReviewResult.ReviewAnswer == "GREEN" {
			status = "VERIFIED"
			tier = "tier2"
		}

		if err := h.Service.UpdateVerificationStatus(c.Request.Context(), userID, status, tier); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update status"})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
