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
	stripe.Key = os.Getenv("STRIPE_SECRET_KEY")
	return &PaymentHandler{Service: svc}
}

type CreatePayPerUseIntentRequest struct {
	Amount   float64 `json:"amount" binding:"required,min=1"`
	Currency string  `json:"currency" binding:"required,len=3,uppercase"`
	Merchant string  `json:"merchant" binding:"required"`
}

// HandleCreateIntent creates a Stripe PaymentIntent for a specific pay-per-use purchase.
// Renamed from HandleCreatePayPerUseIntent for route compatibility.
func (h *PaymentHandler) HandleCreateIntent(c *gin.Context) {
	var req CreatePayPerUseIntentRequest
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

	// Create a PaymentIntent for the specific purchase
	params := &stripe.PaymentIntentParams{
		Amount:   stripe.Int64(int64(req.Amount * 100)),
		Currency: stripe.String(req.Currency),
		AutomaticPaymentMethods: &stripe.PaymentIntentAutomaticPaymentMethodsParams{
			Enabled: stripe.Bool(true),
		},
	}
	params.AddMetadata("user_id", userID.String())
	params.AddMetadata("merchant", req.Merchant)
	params.AddMetadata("type", "pay_per_use")

	pi, err := paymentintent.New(params)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"client_secret": pi.ClientSecret,
	})
}

func (h *PaymentHandler) HandleWebhook(c *gin.Context) {
	const MaxBodyBytes = int64(65536)
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, MaxBodyBytes)
	payload, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Error reading request body"})
		return
	}

	endpointSecret := os.Getenv("STRIPE_WEBHOOK_SECRET")
	event, err := webhook.ConstructEvent(payload, c.GetHeader("Stripe-Signature"), endpointSecret)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid signature"})
		return
	}

	if event.Type == "payment_intent.succeeded" {
		var paymentIntent stripe.PaymentIntent
		err := json.Unmarshal(event.Data.Raw, &paymentIntent)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Error parsing webhook JSON"})
			return
		}

		userIDStr, ok := paymentIntent.Metadata["user_id"]
		if !ok {
			c.JSON(http.StatusOK, gin.H{"status": "ignored_no_user"})
			return
		}

		userID, _ := uuid.Parse(userIDStr)
		amount := float64(paymentIntent.Amount) / 100.0
		merchant := paymentIntent.Metadata["merchant"]

		// Record the transaction directly as a payment
		err = h.Service.ProcessPayment(c.Request.Context(), userID, amount, merchant, paymentIntent.ID)
		if err != nil {
			fmt.Printf("Error processing payment: %v\n", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal Error"})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{"status": "success"})
}
