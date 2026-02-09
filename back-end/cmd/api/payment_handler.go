package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"

	"paysif/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/stripe/stripe-go/v74"
	"github.com/stripe/stripe-go/v74/paymentintent"
	"github.com/stripe/stripe-go/v74/webhook"
)

type PaymentHandler struct {
	Service *service.WalletService
}

func NewPaymentHandler(svc *service.WalletService) *PaymentHandler {
	// Initialize Stripe Key from Env
	stripe.Key = os.Getenv("STRIPE_SECRET_KEY")
	return &PaymentHandler{Service: svc}
}

type CreateIntentRequest struct {
	Amount   float64 `json:"amount" binding:"required"`
	Currency string  `json:"currency" binding:"required"`
}

// HandleCreateIntent creates a Stripe PaymentIntent
func (h *PaymentHandler) HandleCreateIntent(c *gin.Context) {
	var req CreateIntentRequest
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
	// 🛡️ Limit Check: Verify Daily Top-Up Limit
	limits, err := h.Service.FX.GetLimits(c.Request.Context(), userID.String(), req.Currency)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify limits"})
		return
	}

	remaining := limits["remaining_daily_amount"].(float64)
	if req.Amount > remaining {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Daily top-up limit exceeded",
			"remaining": remaining,
		})
		return
	}

	// Step 2: Minimum Check (500 THB)
	if req.Amount < 500 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Minimum top-up is ฿500"})
		return
	}

	// Create a PaymentIntent with amount and currency
	params := &stripe.PaymentIntentParams{
		Amount:   stripe.Int64(int64(req.Amount * 100)), // Convert to cents
		Currency: stripe.String(req.Currency),
		AutomaticPaymentMethods: &stripe.PaymentIntentAutomaticPaymentMethodsParams{
			Enabled: stripe.Bool(true),
		},
	}
	params.AddMetadata("user_id", userID.String())

	pi, err := paymentintent.New(params)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"client_secret": pi.ClientSecret,
	})
}

// HandleWebhook processes Stripe webhooks
func (h *PaymentHandler) HandleWebhook(c *gin.Context) {
	const MaxBodyBytes = int64(65536)
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, MaxBodyBytes)
	payload, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Error reading request body"})
		return
	}

	// Verify Signature
	endpointSecret := os.Getenv("STRIPE_WEBHOOK_SECRET")
	event, err := webhook.ConstructEvent(payload, c.GetHeader("Stripe-Signature"), endpointSecret)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid signature"})
		return
	}

	// Handle Event
	if event.Type == "payment_intent.succeeded" {
		var paymentIntent stripe.PaymentIntent
		err := json.Unmarshal(event.Data.Raw, &paymentIntent)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Error parsing webhook JSON"})
			return
		}

		// Extract Metadata
		userIDStr, ok := paymentIntent.Metadata["user_id"]
		if !ok {
			fmt.Println("Missing user_id in metadata")
			c.JSON(http.StatusOK, gin.H{"status": "ignored_no_user"})
			return
		}

		userID, err := uuid.Parse(userIDStr)
		if err != nil {
			fmt.Println("Invalid user_id uuid")
			c.JSON(http.StatusOK, gin.H{"status": "ignored_invalid_user"})
			return
		}

		amount := float64(paymentIntent.Amount) / 100.0 // Convert cents back to main unit

		// Process Top Up
		err = h.Service.ProcessTopUp(c.Request.Context(), userID, amount, paymentIntent.ID)
		if err != nil {
			fmt.Printf("Error processing topup: %v\n", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal Error"})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{"status": "success"})
}
