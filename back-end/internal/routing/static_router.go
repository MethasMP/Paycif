package routing

import (
	"context"
	"time"

	"paysif/internal/service"

	"github.com/google/uuid"
)

// StaticRouter is the v0 implementation of the Smart Routing Engine.
// It uses simple heuristic references to determine the best path.
type StaticRouter struct {
	walletService *service.WalletService
}

// NewStaticRouter creates a new instance.
func NewStaticRouter(ws *service.WalletService) *StaticRouter {
	return &StaticRouter{walletService: ws}
}

// GetQuote calculates the best payment routes.
func (r *StaticRouter) GetQuote(ctx context.Context, intent PaymentIntent) (*RoutingResponse, error) {
	response := &RoutingResponse{
		IntentID:    uuid.New().String(),
		GeneratedAt: time.Now(),
		Routes:      []PaymentRoute{},
	}

	// 1. Evaluate Internal Wallet
	var balanceMinor int64
	userID, err := uuid.Parse(intent.UserID)
	validUser := err == nil

	if validUser {
		// Silent Fail: If we can't get balance, just assume 0. Don't block the routing.
		bal, err := r.walletService.GetBalance(ctx, userID, intent.Currency)
		if err == nil {
			balanceMinor = bal.Balance
		}
	}

	// Convert Balance to Major Units for comparison
	balanceMajor := float64(balanceMinor) / 100.0

	// 2. Add Internal Wallet Option if sufficient funds
	if balanceMajor >= intent.Amount {
		response.Routes = append(response.Routes, PaymentRoute{
			ID:                 "route_wallet_internal",
			MethodID:           "wallet_main",
			MethodType:         "balance",
			Provider:           "paysif",
			ExchangeRate:       1.0,
			Fee:                0.0,
			TotalCost:          intent.Amount,
			SourceCurrency:     intent.Currency,
			SourceAmount:       intent.Amount,
			SuccessProbability: 0.999,
			SpeedEstimate:      "Instant",
			IsRecommended:      true,
			BadgeText:          "Zero Fees",
		})
	}

	// 3. Add Mock Card Option (Always available fallback)
	cardRecommended := len(response.Routes) == 0

	response.Routes = append(response.Routes, PaymentRoute{
		ID:                 "route_card_visa_4242",
		MethodID:           "card_4242",
		MethodType:         "card",
		Provider:           "visa", // Mock provider
		ExchangeRate:       1.0,
		Fee:                0.0,
		TotalCost:          intent.Amount,
		SourceCurrency:     intent.Currency,
		SourceAmount:       intent.Amount,
		SuccessProbability: 0.98,
		SpeedEstimate:      "~3s",
		IsRecommended:      cardRecommended,
		BadgeText:          "",
	})

	return response, nil
}
