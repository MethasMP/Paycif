package main

import (
	"net/http"
	"paysif/internal/routing"

	"github.com/gin-gonic/gin"
)

type RoutingHandler struct {
	Router routing.Service
}

func NewRoutingHandler(r routing.Service) *RoutingHandler {
	return &RoutingHandler{Router: r}
}

type GetQuoteRequest struct {
	Amount     float64 `form:"amount" binding:"required,gt=0"`
	Currency   string  `form:"currency" binding:"required,len=3,uppercase"`
	MerchantID string  `form:"merchant_id"`
}

func (h *RoutingHandler) HandleGetQuote(c *gin.Context) {
	// 1. Extract Identity (from Auth Middleware)
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User ID not found in context"})
		return
	}

	// 2. Extract and Validate Query Params
	var req GetQuoteRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	intent := routing.PaymentIntent{
		UserID:     userID,
		Amount:     req.Amount,
		Currency:   req.Currency,
		MerchantID: req.MerchantID,
	}

	// 3. Get Smart Quote
	quote, err := h.Router.GetQuote(c.Request.Context(), intent)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate quote"})
		return
	}

	c.JSON(http.StatusOK, quote)
}
