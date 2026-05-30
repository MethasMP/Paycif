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

	// 1. Evaluate Internal Wallet - skipped for pay-per-use
	// (Internal wallet balance is deprecated)

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
