package service

import (
	"context"
	"fmt"
	"log"
	"sync"
)

// PayoutResult represents the response from any payment provider.
type PayoutResult struct {
	ExternalID string
	Status     string // SUCCESS, PENDING, FAILED
	RawMessage string
}

// PaymentProvider is the interface that every payment gateway must implement.
type PaymentProvider interface {
	GetName() string
	// Payout sends money to a recipient (e.g., PromptPay ID).
	Payout(ctx context.Context, amount int64, currency string, recipientID string, recipientName string, reference string) (*PayoutResult, error)
}

// PaymentEngine orchestrates multiple payment providers with thread-safety.
type PaymentEngine struct {
	mu              sync.RWMutex
	providers       map[string]PaymentProvider
	defaultProvider string
}

// NewPaymentEngine creates a new instance of PaymentEngine.
func NewPaymentEngine(defaultProviderName string) *PaymentEngine {
	return &PaymentEngine{
		providers:       make(map[string]PaymentProvider),
		defaultProvider: defaultProviderName,
	}
}

// RegisterProvider adds a new provider to the engine. Thread-safe.
func (e *PaymentEngine) RegisterProvider(p PaymentProvider) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.providers[p.GetName()] = p
	log.Printf("💳 PaymentEngine: Registered provider: %s", p.GetName())
}

// SetDefaultProvider changes the active provider. Thread-safe.
func (e *PaymentEngine) SetDefaultProvider(name string) error {
	e.mu.Lock()
	defer e.mu.Unlock()
	if _, ok := e.providers[name]; !ok {
		return fmt.Errorf("provider %s not found", name)
	}
	e.defaultProvider = name
	return nil
}

// ExecutePayout routes the payout request to the default or specific provider.
func (e *PaymentEngine) ExecutePayout(ctx context.Context, providerName string, amount int64, currency string, recipientID string, recipientName string, reference string) (*PayoutResult, error) {
	e.mu.RLock()
	name := providerName
	if name == "" {
		name = e.defaultProvider
	}

	provider, ok := e.providers[name]
	e.mu.RUnlock()

	if !ok {
		return nil, fmt.Errorf("payment provider %s not found or not registered", name)
	}

	log.Printf("🚀 PaymentEngine: Routing payout of %d %s via %s", amount, currency, name)
	return provider.Payout(ctx, amount, currency, recipientID, recipientName, reference)
}

// --- Implementation Stubs for Omise and Wise ---

// OmiseProvider implements PaymentProvider for Omise.
type OmiseProvider struct {
	APIKey string
}

func (o *OmiseProvider) GetName() string { return "omise" }
func (o *OmiseProvider) Payout(ctx context.Context, amount int64, currency string, recipientID string, recipientName string, reference string) (*PayoutResult, error) {
	// Mock implementation
	log.Printf("[Omise] Processing payout of %d %s to %s", amount, currency, recipientID)
	return &PayoutResult{
		ExternalID: "omise_tx_123",
		Status:     "SUCCESS",
		RawMessage: "Processed via Omise Mock API",
	}, nil
}

// WiseProvider implements PaymentProvider for Wise.
type WiseProvider struct {
	Token string
}

func (w *WiseProvider) GetName() string { return "wise" }
func (w *WiseProvider) Payout(ctx context.Context, amount int64, currency string, recipientID string, recipientName string, reference string) (*PayoutResult, error) {
	// Mock implementation
	log.Printf("[Wise] Processing payout of %d %s to %s", amount, currency, recipientID)
	return &PayoutResult{
		ExternalID: "wise_tx_456",
		Status:     "SUCCESS",
		RawMessage: "Processed via Wise Mock API",
	}, nil
}
