package usecase

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"strings"

	fxrpc "paysif/internal/adapter/grpc"

	"github.com/shopspring/decimal"
)

// FXService handles currency exchange operations.
type FXService struct {
	DB         *sql.DB
	GRPCClient fxrpc.FXClientInterface
}

// NewFXService creates a new FXService.
func NewFXService(db *sql.DB, grpcClient fxrpc.FXClientInterface) *FXService {
	return &FXService{
		DB:         db,
		GRPCClient: grpcClient,
	}
}

// QuoteDetails holds the transparent breakdown of the calculated rate.
type QuoteDetails struct {
	BaseFiatAmount    decimal.Decimal
	PaycifPlatformFee decimal.Decimal
	TotalFiatAmount   decimal.Decimal
	MidMarketRate     decimal.Decimal
	CorridorSpread    decimal.Decimal
	CorridorType      string
}

// CalculateDynamicQuote calculates the dynamic quote based on the Transparent Corridor Spread strategy.
func (s *FXService) CalculateDynamicQuote(ctx context.Context, targetAmountUSD float64, fiatCurrency string, achQuote *QuoteResult, corridorType string) (*QuoteDetails, error) {
	// 1. Determine Corridor Spread (The "Wise" Transparent Fee)
	spreadPct := decimal.NewFromFloat(0.015) // Card Default: 1.5%
	if corridorType == "CRYPTO" {
		spreadPct = decimal.NewFromFloat(0.02) // Crypto: 2.0%
	}

	// 2. Parse Alchemy Pay Live Data (Base Cost)
	price, err := decimal.NewFromString(achQuote.Price)
	if err != nil {
		return nil, fmt.Errorf("invalid price from ACH: %v", err)
	}

	// 3. Calculate Base Fiat Needed
	// targetAmountUSD represents the USDC required by SQRIL
	targetCrypto := decimal.NewFromFloat(targetAmountUSD)

	// Add ACH Network Fee (in Crypto) to target before converting to Fiat
	networkFee, _ := decimal.NewFromString(achQuote.NetworkFee)
	totalCryptoNeeded := targetCrypto.Add(networkFee)

	baseFiatAmount := totalCryptoNeeded.Mul(price)

	// Add ACH RampFee
	rampFee, _ := decimal.NewFromString(achQuote.RampFee)
	baseFiatAmount = baseFiatAmount.Add(rampFee)

	// 4. Calculate Paycif Platform Fee (Our Dynamic Corridor Spread)
	paycifFee := baseFiatAmount.Mul(spreadPct)

	// 5. Total Fiat Amount
	totalFiatAmount := baseFiatAmount.Add(paycifFee)

	return &QuoteDetails{
		BaseFiatAmount:    baseFiatAmount,
		PaycifPlatformFee: paycifFee,
		TotalFiatAmount:   totalFiatAmount,
		MidMarketRate:     price,
		CorridorSpread:    spreadPct,
		CorridorType:      corridorType,
	}, nil
}

// ConvertToBase converts an amount in a given currency to THB (Base).
// Returns (baseAmount, usedRate, error)
func (s *FXService) ConvertToBase(ctx context.Context, amount int64, currency string) (int64, decimal.Decimal, error) {
	if currency == "THB" {
		return amount, decimal.NewFromInt(1), nil
	}

	// 1. Try Rust FX Engine (High Performance)
	if s.GRPCClient != nil {
		resp, err := s.GRPCClient.Convert(ctx, currency, "THB", amount, "srv-req")
		if err == nil && resp.Success {
			// Success!
			rate, _ := decimal.NewFromString(resp.RateUsed)
			return resp.ConvertedAmount, rate, nil
		}
		// If failed, log and fall back to DB
		log.Printf("⚠️ Rust FX Engine unreachable or failed: %v. Falling back to DB.", err)
	}

	// 2. Fallback: Stateless Query Logic
	// This ensures survivability if the microservice is down.
	var rateStr string
	convQuery := "SELECT provider_rate FROM exchange_rates WHERE from_currency = $1 AND to_currency = 'THB'"

	err := s.DB.QueryRowContext(ctx, convQuery, strings.ToUpper(currency)).Scan(&rateStr)

	if err != nil {
		return 0, decimal.Zero, fmt.Errorf("no exchange rate found for %s/THB (DB Fallback): %w", currency, err)
	}

	rate, err := decimal.NewFromString(rateStr)
	if err != nil {
		return 0, decimal.Zero, fmt.Errorf("invalid decimal in DB: %w", err)
	}

	amountDec := decimal.NewFromInt(amount)
	baseAmountDec := amountDec.Mul(rate)

	return baseAmountDec.IntPart(), rate, nil
}

// GetLimits returns the daily limit status from Rust FX Engine or dummy Fallback
func (s *FXService) GetLimits(ctx context.Context, userID, currency string) (map[string]interface{}, error) {
	// 1. Try Rust FX Engine
	if s.GRPCClient != nil {
		resp, err := s.GRPCClient.GetLimits(ctx, userID, currency)
		if err == nil {
			return map[string]interface{}{
				"max_daily_amount":       resp.MaxDailyAmount,
				"remaining_daily_amount": resp.RemainingDailyAmount,
				"current_daily_total":    resp.CurrentDailyTotal,
				"max_transaction_amount": resp.MaxTransactionAmount,
			}, nil
		}
		log.Printf("⚠️ Rust Limit Check unreachable or failed: %v. Returning fallback.", err)
	}

	// 2. Fallback: Return dummy limits since topups are deprecated in Pay-per-use model
	return map[string]interface{}{
		"max_daily_amount":       20000.0,
		"remaining_daily_amount": 20000.0,
		"current_daily_total":    0.0,
		"max_transaction_amount": 20000.0,
	}, nil
}

// PreValidateTransfer checks signature and limits via Rust FX Engine
func (s *FXService) PreValidateTransfer(ctx context.Context, userID, currency string, amount int64, publicKey, signature, message []byte) (bool, string, error) {
	if s.GRPCClient == nil {
		return false, "Service Unavailable", fmt.Errorf("Rust FX Engine unavailable")
	}

	resp, err := s.GRPCClient.PreValidateTransfer(ctx, userID, currency, amount, publicKey, signature, message)
	if err != nil {
		return false, "Validation Error", err
	}

	if !resp.Valid {
		return false, resp.ErrorMessage, nil
	}

	return true, "", nil
}
