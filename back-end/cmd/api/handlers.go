package main

import (
	"fmt"
	"log"
	"net/http"
	"paysif/internal/service"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// TransferHandler holds dependencies for transfer operations.
type TransferHandler struct {
	Service          *service.WalletService
	SignatureService *service.SignatureService
}

// TransferRequestDTO matches the expected JSON input.
// We map this to service.TransferRequest.
type TransferRequestDTO struct {
	FromWalletID   string `json:"from_wallet_id" binding:"required,uuid"`
	ToWalletID     string `json:"to_wallet_id" binding:"required,uuid"`
	Amount         int64  `json:"amount" binding:"required,gt=0"`
	Currency       string `json:"currency" binding:"required,len=3,uppercase"`
	IdempotencyKey string `json:"idempotency_key" binding:"required,uuid"`
	Description    string `json:"description" binding:"max=200"`
}

// HandleTransfer processes the transfer request.
func (h *TransferHandler) HandleTransfer(c *gin.Context) {
	var dto TransferRequestDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	fromID, _ := uuid.Parse(dto.FromWalletID)
	toID, _ := uuid.Parse(dto.ToWalletID)

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
		log.Printf("⚠️ Signature Error: %v for user %s\n", err, userID)
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	// ⬇️ DEPRECATED: Go-based Signature Verification (Offloaded to Rust FX Engine)
	// isValid, err := h.SignatureService.VerifySignature(publicKey, signature, dto.IdempotencyKey)
	// if err != nil || !isValid {
	// 	log.Printf("❌ Signature Verification Failure for User %s, Device %s\n", userID, deviceId)
	// 	c.JSON(http.StatusUnauthorized, gin.H{"error": "Request integrity check failed"})
	// 	return
	// }

	req := service.TransferRequest{
		UserID:       userID,
		FromWalletID: fromID,
		ToWalletID:   toID,
		Amount:       dto.Amount,
		Currency:     dto.Currency,
		ReferenceID:  dto.IdempotencyKey,
		Description:  dto.Description,
		// Security Offload to Rust
		PublicKey:     publicKey,
		Signature:     signature,
		SignedPayload: dto.IdempotencyKey,
	}

	resp, err := h.Service.Transfer(c.Request.Context(), req)
	if err != nil {
		// Differentiate errors if possible, but generic 400 or 500 for now.
		// If custom error types existed, we could be more specific.
		// For robustness, assume logical errors are 400 and system errors 500.
		// Simple approach: non-nil error from service -> 400 (e.g. insufficient funds) or 500.
		// Given strict instructions: "409 for duplicate idempotency keys" is handled below on success.
		// We'll treat generic errors as 500 for safety, or 400 if validation.
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if resp.UsedExisting {
		c.JSON(http.StatusConflict, gin.H{
			"error":          "Idempotency key conflict",
			"transaction_id": resp.TransactionID,
			"message":        "Transaction already processed with this key",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"transaction_id": resp.TransactionID,
		"status":         "success",
	})
}

// HandleBalance returns the balance for the authenticated user.
func (h *TransferHandler) HandleBalance(c *gin.Context) {
	currency := strings.ToUpper(strings.TrimSpace(c.Query("currency")))
	if len(currency) != 3 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid currency format (ISO 4217 required)"})
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

	balance, err := h.Service.GetBalance(c.Request.Context(), userID, currency)
	if err != nil {
		// Could differentiate 404 vs 500
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, balance)
}

// HandleGetTransactions retrieves the transaction history for a wallet.
func (h *TransferHandler) HandleGetTransactions(c *gin.Context) {
	walletIDStr := strings.TrimSpace(c.Query("wallet_id"))
	if walletIDStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "wallet_id query param required"})
		return
	}

	walletID, err := uuid.Parse(walletIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid wallet_id"})
		return
	}

	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User unauthorized"})
		return
	}
	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.Error(err) // Log invalid user ID error
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID in token"})
		return
	}

	transactions, err := h.Service.GetTransactions(c.Request.Context(), userID, walletID)
	if err != nil {
		// Differentiate unauthorized vs internal? Service returns "unauthorized" error text
		if err.Error() == "unauthorized: wallet does not belong to user" {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
		c.Error(err) // Log the actual database/service error
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal Server Error"})
		return
	}

	c.JSON(http.StatusOK, transactions)
}

// HandleGetLatestRate retrieves the exchange rate for the user's home currency against THB.
func (h *TransferHandler) HandleGetLatestRate(c *gin.Context) {
	homeCurrency := strings.ToUpper(strings.TrimSpace(c.Query("home_currency")))
	if homeCurrency == "" {
		homeCurrency = "USD"
	}

	if len(homeCurrency) != 3 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid currency format"})
		return
	}

	// Base currency is fixed to THB for this iteration (Thai Wallet System)
	baseCurrency := "THB"

	// If home currency is THB, return 1:1
	if homeCurrency == baseCurrency {
		c.JSON(http.StatusOK, gin.H{
			"from":       baseCurrency,
			"to":         baseCurrency,
			"rate":       1.0,
			"updated_at": time.Now(),
		})
		return
	}

	// Fetch Rate: Home -> THB (e.g. 1 EUR = 40 THB)
	rateResp, err := h.Service.GetExchangeRate(c.Request.Context(), homeCurrency, baseCurrency)
	if err != nil {
		// Fallback to USD if specific currency not found and we didn't ask for USD
		if homeCurrency != "USD" {
			log.Printf("Rate not found for %s, falling back to USD", homeCurrency)
			fallbackResp, errFb := h.Service.GetExchangeRate(c.Request.Context(), "USD", baseCurrency)
			if errFb == nil {
				rateResp = fallbackResp
			} else {
				// Even fallback failed
				c.JSON(http.StatusNotFound, gin.H{"error": "Exchange rate not available"})
				return
			}
		} else {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
	}

	// ETag & Cache-Control (Article Step 2)
	etag := fmt.Sprintf("\"%d\"", rateResp.UpdatedAt.UnixNano())
	c.Header("ETag", etag)
	c.Header("Cache-Control", "public, max-age=10") // Short cache for rates

	if match := c.GetHeader("If-None-Match"); match == etag {
		c.Status(http.StatusNotModified)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"from":       rateResp.FromCurrency,
		"to":         rateResp.ToCurrency,
		"rate":       rateResp.ProviderRate,
		"updated_at": rateResp.UpdatedAt,
	})
}

// HandleGetLimits returns the user's daily transaction limits.
func (h *TransferHandler) HandleGetLimits(c *gin.Context) {
	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User unauthorized"})
		return
	}
	// Assuming userID is valid UUID as middleware checks
	
	// Default to THB for now
	currency := "THB"

	// Fetch limits from Rust FX Engine via Service
	limits, err := h.Service.FX.GetLimits(c.Request.Context(), userIDStr.(string), currency)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch limits: " + err.Error()})
		return
	}

	// ETag & Cache-Control (Article Step 2)
	// Create a unique fingerprint based on critical values
	fingerprint := fmt.Sprintf("%v-%v-%v-%v", 
		limits["max_daily_amount"], 
		limits["current_daily_total"], 
		limits["remaining_daily_amount"],
		userIDStr)
	
	// Simple hash for ETag (or just raw string if short enough, but clean is better)
	// We use FNV or just string since it's short.
	etag := fmt.Sprintf("\"%x\"", fingerprint) 

	c.Header("ETag", etag)
	c.Header("Cache-Control", "private, max-age=0, must-revalidate") // Private user data, validate always but save bandwidth

	if match := c.GetHeader("If-None-Match"); match == etag {
		c.Status(http.StatusNotModified)
		return
	}

	// Map to Frontend Expected Keys (CamelCase or SnakeCase matching Edge Function)
	// Edge Function returns: max_daily_baht, current_total_baht, remaining_limit_baht
	response := gin.H{
		"max_daily_baht":           limits["max_daily_amount"],
		"current_total_baht":       limits["current_daily_total"],
		"remaining_limit_baht":     limits["remaining_daily_amount"],
		"min_per_transaction_baht": 500.0, // Hardcoded minimum for now
	}

	c.JSON(http.StatusOK, response)
}
