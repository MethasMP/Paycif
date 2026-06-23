package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"

	"paysif/internal/usecase"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type PaymentHandler struct {
	Service *usecase.WalletService
	ACH     *usecase.AlchemyPayAdapter
	FX      *usecase.FXService
}

func NewPaymentHandler(svc *usecase.WalletService, ach *usecase.AlchemyPayAdapter, fx *usecase.FXService) *PaymentHandler {
	return &PaymentHandler{Service: svc, ACH: ach, FX: fx}
}

// --- Check Region ---

// HandleCheckRegion checks whether ACH supports the tourist's country via IP.
// Frontend calls this before rendering the payment screen.
func (h *PaymentHandler) HandleCheckRegion(c *gin.Context) {
	ip := c.ClientIP()
	if ip == "" || ip == "::1" || ip == "127.0.0.1" {
		// In dev/sandbox treat localhost as available
		c.JSON(http.StatusOK, gin.H{"available": true, "country": "TH"})
		return
	}

	result, err := h.ACH.CheckRegion(c.Request.Context(), ip)
	if err != nil {
		log.Printf("ACH region check failed for IP %s: %v", ip, err)
		// Fail open — let the flow continue, ACH page will handle it
		c.JSON(http.StatusOK, gin.H{"available": true, "country": ""})
		return
	}
	c.JSON(http.StatusOK, gin.H{"available": result.Available, "country": result.Country})
}

// --- Quote ---

type QuoteRequest struct {
	Amount       int64  `json:"amount" binding:"required,gt=0"`
	SqrilTxID    string `json:"sqril_tx_id" binding:"required"`
	FiatCurrency string `json:"fiat_currency" binding:"required"`
	CorridorType string `json:"corridor_type" binding:"required"` // "CARD" or "CRYPTO"
}

// HandleGetQuote returns a dynamically calculated quote including the transparent spread.
func (h *PaymentHandler) HandleGetQuote(c *gin.Context) {
	var req QuoteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 1. Get Target USD Amount from SQRIL
	prov, ok := h.Service.PaymentEngine.GetProvider("sqril")
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Off-ramp provider unavailable"})
		return
	}
	sqril := prov.(*usecase.SqrilProvider)
	
	// Use a mock customer ID for quote
	sqrilQuote, err := sqril.GetQuotation(c.Request.Context(), req.SqrilTxID, "quote_user", req.Amount)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to get off-ramp quotation: " + err.Error()})
		return
	}

	// 2. Get Live ACH Price (using dummy 100 to get the rate)
	achQuote, err := h.ACH.GetQuote(c.Request.Context(), "100", req.FiatCurrency, "USDC", "BASE")
	if err != nil {
		log.Printf("ACH quote failed: %v", err)
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to fetch live rate. Please try again."})
		return
	}

	// 3. Calculate Dynamic Quote
	quoteDetails, err := h.FX.CalculateDynamicQuote(c.Request.Context(), sqrilQuote.AmountUSD, req.FiatCurrency, achQuote, req.CorridorType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to calculate dynamic quote: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"base_fiat_amount":    quoteDetails.BaseFiatAmount.StringFixed(2),
		"paycif_platform_fee": quoteDetails.PaycifPlatformFee.StringFixed(2),
		"total_fiat_amount":   quoteDetails.TotalFiatAmount.StringFixed(2),
		"mid_market_rate":     quoteDetails.MidMarketRate.StringFixed(4),
		"corridor_spread":     quoteDetails.CorridorSpread.StringFixed(4),
		"corridor_type":       quoteDetails.CorridorType,
		"crypto_target":       sqrilQuote.AmountUSD,
		"fiat_currency":       req.FiatCurrency,
		"crypto":              "USDC",
		"network":             "BASE",
	})
}

// --- Create Intent + ACH Order ---

type CreatePayoutIntentRequest struct {
	Amount        int64  `json:"amount" binding:"required,gt=0"` // satangs
	FiatCurrency  string `json:"fiat_currency" binding:"required"`
	PromptPayID   string `json:"promptpay_id" binding:"required"`
	RecipientName string `json:"recipient_name" binding:"required"`
	SqrilTxID     string `json:"sqril_tx_id" binding:"required"`
	CorridorType  string `json:"corridor_type" binding:"required"`
	Email         string `json:"email"` // optional, pre-fills ACH KYC
}

// HandleCreateIntent validates the SQRIL quote, stores a PayoutIntent, calls ACH to create
// the on-ramp order, and returns the ACH checkout URL for the Flutter app to open.
func (h *PaymentHandler) HandleCreateIntent(c *gin.Context) {
	var req CreatePayoutIntentRequest
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

	// 1. Validate SQRIL quote is still alive before we commit to anything
	prov, ok := h.Service.PaymentEngine.GetProvider("sqril")
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Off-ramp provider unavailable"})
		return
	}
	sqril, ok := prov.(*usecase.SqrilProvider)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Off-ramp provider misconfigured"})
		return
	}
	sqrilQuote, err := sqril.GetQuotation(c.Request.Context(), req.SqrilTxID, "cust_paycif_"+userID.String(), req.Amount)
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

	// 2. Calculate Final Exact Fiat Amount dynamically
	achQuote, err := h.ACH.GetQuote(c.Request.Context(), "100", req.FiatCurrency, "USDC", "BASE")
	if err != nil {
		log.Printf("ACH quote failed: %v", err)
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to fetch live rate. Please try again."})
		return
	}
	quoteDetails, err := h.FX.CalculateDynamicQuote(c.Request.Context(), sqrilQuote.AmountUSD, req.FiatCurrency, achQuote, req.CorridorType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to calculate dynamic quote: " + err.Error()})
		return
	}

	// 3. Persist the intent — this is our idempotency anchor
	intentID := uuid.New()
	intent := usecase.PayoutIntent{
		ID:            intentID,
		UserID:        userID,
		Amount:        req.Amount,
		PromptPayID:   req.PromptPayID,
		RecipientName: req.RecipientName,
		SqrilTxID:     req.SqrilTxID,
		Status:        "PENDING",
	}
	if err := h.Service.CreatePayoutIntent(c.Request.Context(), intent); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create payment intent: " + err.Error()})
		return
	}

	// 4. Call ACH to create the on-ramp order and get the checkout URL
	poolAddress := os.Getenv("POOL_WALLET_ADDRESS") // SQRIL/partner-controlled USDC wallet
	redirectURL := os.Getenv("ACH_REDIRECT_URL")    // deep-link back to Paycif app after payment
	webhookURL := os.Getenv("ACH_WEBHOOK_URL")      // our /hooks/alchemypay endpoint

	fiatAmountStr := quoteDetails.TotalFiatAmount.StringFixed(2)
	order, err := h.ACH.CreateOrder(c.Request.Context(), usecase.OnRampOrderParams{
		MerchantOrderNo: intentID.String(),
		FiatCurrency:    req.FiatCurrency,
		FiatAmount:      fiatAmountStr,
		Crypto:          "USDC",
		Network:         "BASE",
		Address:         poolAddress,
		Email:           req.Email,
		RedirectURL:     redirectURL,
		CallbackURL:     webhookURL,
	})
	if err != nil {
		log.Printf("ACH create order failed for intent %s: %v", intentID, err)
		// Roll back the intent so tourist can retry cleanly
		_ = h.Service.UpdatePayoutIntentStatus(c.Request.Context(), intentID, "ACH_FAILED")
		c.JSON(http.StatusBadGateway, gin.H{"error": "Payment provider unavailable. Please try again."})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"intent_id":          intentID.String(),
		"web_url":            order.WebURL, // Flutter opens this in a WebView/browser
		"total_fiat_charged": fiatAmountStr,
	})
}

// --- Webhook ---

// AlchemyPayWebhookPayload matches the ACH callback body.
// ACH puts the signature inside the JSON body as "newSignature".
type AlchemyPayWebhookPayload struct {
	OrderNo         string `json:"orderNo"`
	MerchantOrderNo string `json:"merchantOrderNo"`
	Status          string `json:"status"` // PAY_SUCCESS | PAY_FAIL | FINISHED
	Amount          string `json:"amount"`
	Currency        string `json:"currency"`
	CryptoAmount    string `json:"cryptoAmount"`
	Crypto          string `json:"crypto"`
	Network         string `json:"network"`
	UserId          string `json:"userId"`
	NewSignature    string `json:"newSignature"`
}

// HandleWebhook receives ACH payment events and triggers the SQRIL off-ramp on FINISHED.
func (h *PaymentHandler) HandleWebhook(c *gin.Context) {
	const maxBody = int64(65536)
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBody)
	payload, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Error reading request body"})
		return
	}

	var data AlchemyPayWebhookPayload
	if err := json.Unmarshal(payload, &data); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Error parsing webhook JSON"})
		return
	}

	// Verify signature using ACH's HMAC-SHA256 scheme
	ts := c.GetHeader("timestamp")
	if ts == "" {
		ts = c.GetHeader("ach-access-timestamp") // fallback for potential testing variance
	}
	// Webhooks path is typically /hooks/alchemypay
	if !h.ACH.VerifyWebhookSignature(ts, "POST", "/hooks/alchemypay", string(payload), data.NewSignature) {
		log.Printf("ACH webhook signature mismatch for order %s", data.MerchantOrderNo)
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid signature"})
		return
	}

	log.Printf("ACH webhook order=%s status=%s", data.MerchantOrderNo, data.Status)

	if data.Status != "FINISHED" {
		// PAY_SUCCESS and PAY_FAIL are informational — no action needed yet
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
		return
	}

	intentUUID, err := uuid.Parse(data.MerchantOrderNo)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid merchant order number"})
		return
	}

	intent, err := h.Service.GetPayoutIntent(c.Request.Context(), intentUUID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Payout intent not found"})
		return
	}

	if intent.Status == "COMPLETED" {
		c.JSON(http.StatusOK, gin.H{"status": "already_processed"})
		return
	}

	// Record the on-ramp credit in the ledger
	desc := fmt.Sprintf("Alchemy Pay: %s %s", data.Amount, data.Currency)
	if err := h.Service.ProcessPayment(c.Request.Context(), intent.UserID, float64(intent.Amount)/100.0, desc, data.OrderNo); err != nil {
		log.Printf("Ledger credit failed for intent %s: %v", intent.ID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Ledger processing error"})
		return
	}

	// Trigger SQRIL off-ramp → PromptPay
	payoutResp, err := h.Service.PayoutToPromptPay(c.Request.Context(), usecase.PayoutRequest{
		UserID:         intent.UserID,
		Amount:         intent.Amount,
		PromptPayID:    intent.PromptPayID,
		RecipientName:  intent.RecipientName,
		IdempotencyKey: intent.ID.String(),
		SqrilTxID:      intent.SqrilTxID,
	})
	if err != nil {
		log.Printf("Instant payout failed for intent %s (outbox will retry): %v", intent.ID, err)
		_ = h.Service.UpdatePayoutIntentStatus(c.Request.Context(), intent.ID, "PAYMENT_SUCCESS_PAYOUT_PENDING")
		c.JSON(http.StatusOK, gin.H{"status": "payout_pending_retry"})
		return
	}

	_ = h.Service.UpdatePayoutIntentStatus(c.Request.Context(), intent.ID, "COMPLETED")
	log.Printf("Payout complete for intent %s status=%s", intent.ID, payoutResp.Status)
	c.JSON(http.StatusOK, gin.H{"status": "success"})
}
