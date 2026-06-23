package main

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"paysif/internal/usecase"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// KYCHandler handles identity verification requests via the delegated KYC provider.
type KYCHandler struct {
	Service *usecase.KYCService
}

// NewKYCHandler creates a new KYCHandler.
func NewKYCHandler(svc *usecase.KYCService) *KYCHandler {
	return &KYCHandler{Service: svc}
}

// initiateKYCRequest is the JSON input for starting a KYC flow.
type initiateKYCRequest struct {
	KycPlatform string `json:"kyc_platform" binding:"required"` // "sumsub" or "onfido"
	KycType     string `json:"kyc_type" binding:"required"`     // e.g. "1"
	RedirectURL string `json:"redirect_url"`
}

// HandleRegisterOnRampCustomer initiates a KYC session with Alchemy Pay and returns the verification URL.
func (h *KYCHandler) HandleRegisterOnRampCustomer(c *gin.Context) {
	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid user ID"})
		return
	}

	var req initiateKYCRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	callbackURL := os.Getenv("ALCHEMY_PAY_KYC_CALLBACK_URL")
	if callbackURL == "" {
		callbackURL = os.Getenv("API_BASE_URL") + "/api/v1/kyc/onramp-webhook"
	}

	svcReq := usecase.RegisterOnRampCustomerRequest{
		UserID:      userID,
		KycPlatform: req.KycPlatform,
		KycType:     req.KycType,
		CallbackURL: callbackURL,
		RedirectURL: req.RedirectURL,
	}

	result, err := h.Service.RegisterOnRampCustomer(c.Request.Context(), svcReq)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if result.AlreadyRegistered {
		c.JSON(http.StatusOK, gin.H{
			"status":  "already_registered",
			"message": "User is already registered for KYC. Check /kyc/status for current state.",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":  "pending_verification",
		"kyc_url": result.KycURL,
		"message": "Redirect the user to kyc_url to complete identity verification.",
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

// HandleOnRampKycWebhook handles KYC result callbacks from Alchemy Pay.
// Alchemy Pay may deliver the same notification multiple times — this handler is idempotent.
func (h *KYCHandler) HandleOnRampKycWebhook(c *gin.Context) {
	const maxBodyBytes = int64(65536)
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBodyBytes)
	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Error reading request body"})
		return
	}

	// Verify Alchemy Pay HMAC-SHA256 signature when the KYC client is configured.
	if h.Service != nil && h.Service.KYCClient != nil && h.Service.KYCClient.AppKey() != "" {
		ts := c.GetHeader("ach-access-timestamp")
		sig := c.GetHeader("ach-access-sign")
		// Webhooks arrive as POST to /api/v1/kyc/onramp-webhook
		if !h.Service.KYCClient.VerifyWebhookSignature(ts, "POST", "/api/v1/kyc/onramp-webhook", string(body), sig) {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid signature"})
			return
		}
	}

	var payload usecase.AchWebhookPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid payload"})
		return
	}

	if payload.Email == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Missing email in webhook payload"})
		return
	}

	if err := h.Service.SyncOnRampKycStatus(c.Request.Context(), payload); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to sync KYC status"})
		return
	}

	// Must return HTTP 200 to stop Alchemy Pay retry schedule.
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
