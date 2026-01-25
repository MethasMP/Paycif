package main

import (
	"net/http"
	"strconv"
	"paysif/internal/routing"

	"github.com/gin-gonic/gin"
)

type RoutingHandler struct {
	Router routing.Service
}

func NewRoutingHandler(r routing.Service) *RoutingHandler {
	return &RoutingHandler{Router: r}
}

func (h *RoutingHandler) HandleGetQuote(c *gin.Context) {
	// 1. Extract Identity (from Auth Middleware)
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User ID not found in context"})
		return
	}

	// 2. Extract Intent
	amountStr := c.Query("amount")
	currency := c.Query("currency")
	merchantID := c.Query("merchant_id")

	if amountStr == "" || currency == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Amount and currency are required"})
		return
	}

	amount, err := strconv.ParseFloat(amountStr, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid amount format"})
		return
	}

	intent := routing.PaymentIntent{
		UserID:     userID,
		Amount:     amount,
		Currency:   currency,
		MerchantID: merchantID,
	}

	// 3. Get Smart Quote
	quote, err := h.Router.GetQuote(c.Request.Context(), intent)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate quote"})
		return
	}

	c.JSON(http.StatusOK, quote)
}
