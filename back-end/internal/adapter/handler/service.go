package routing

import "context"

// Service defines the interface for the Smart Routing Engine.
type Service interface {
	// GetQuote calculates the best payment routes for a given intent.
	// It evaluates available methods, risk, and economics to return a ranked list.
	GetQuote(ctx context.Context, intent PaymentIntent) (*RoutingResponse, error)
}
