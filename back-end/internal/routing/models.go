package routing

import "time"

// PaymentIntent represents what the user wants to achieve.
type PaymentIntent struct {
	UserID     string  `json:"user_id"`
	Amount     float64 `json:"amount"` // Major units (e.g., 100.50)
	Currency   string  `json:"currency"`
	MerchantID string  `json:"merchant_id,omitempty"`
}

// PaymentRoute represents a specific path for execution.
type PaymentRoute struct {
	ID         string `json:"route_id"`
	MethodID   string `json:"method_id"`   // "card_123", "wallet_balance"
	MethodType string `json:"method_type"` // "card", "balance", "promptpay"
	Provider   string `json:"provider"`    // "stripe", "omise", "internal"

	// Economics
	ExchangeRate   float64 `json:"exchange_rate"`
	Fee            float64 `json:"fee"`
	TotalCost      float64 `json:"total_cost"`      // Amount + Fee
	SourceCurrency string  `json:"source_currency"` // e.g., "USD" if paying with US Card
	SourceAmount   float64 `json:"source_amount"`   // Estimated charge in home currency

	// Intelligence Signals
	SuccessProbability float64 `json:"success_probability"` // 0.0 - 1.0
	SpeedEstimate      string  `json:"speed_estimate"`      // "Instant", "~5s", "~1m"
	IsRecommended      bool    `json:"is_recommended"`

	// UX
	BadgeText string `json:"badge_text,omitempty"` // "Best Rate", "Fastest"
}

// RoutingResponse is the output of the engine.
type RoutingResponse struct {
	IntentID    string         `json:"intent_id"`
	Routes      []PaymentRoute `json:"routes"`
	GeneratedAt time.Time      `json:"generated_at"`
}
