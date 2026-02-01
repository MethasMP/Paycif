package service

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"strings"
	"time"

	"github.com/shopspring/decimal"
)

// FXService handles currency exchange operations.
type FXService struct {
	DB *sql.DB
}

// NewFXService creates a new FXService.
func NewFXService(db *sql.DB) *FXService {
	return &FXService{DB: db}
}

// ExchangeRateAPIResponse structure for open.er-api.com
type ExchangeRateAPIResponse struct {
	Result string             `json:"result"`
	Rates  map[string]float64 `json:"rates"`
}

// StartFXScheduler starts the background task to simulate rate updates.
func (s *FXService) StartFXScheduler(ctx context.Context) {
	// Update less frequently (e.g. every 15 minutes) as per user request
	ticker := time.NewTicker(15 * time.Minute)
	go func() {
		log.Println("FX Simulation Scheduler started...")
		// Run immediately on start
		s.SimulateRates(ctx)

		for {
			select {
			case <-ticker.C:
				s.SimulateRates(ctx)
			case <-ctx.Done():
				ticker.Stop()
				return
			}
		}
	}()
}

// SimulateRates updates rates based on existing values with random noise.
func (s *FXService) SimulateRates(ctx context.Context) {
	currencies := []string{"EUR", "USD", "RUB", "INR", "AUD"}
	targetCurrency := "THB"

	for _, fromCurr := range currencies {
		// Stateless Query for Simulation
		var currentRateStr string
		safeFrom := strings.ReplaceAll(strings.ToUpper(fromCurr), "'", "''")
		simQuery := fmt.Sprintf("SELECT mid_rate FROM exchange_rates WHERE from_currency = '%s' AND to_currency = 'THB'", safeFrom)
		
		err := s.DB.QueryRowContext(ctx, simQuery).Scan(&currentRateStr)

		if err == sql.ErrNoRows || currentRateStr == "" {
			// Init: Fetch from API if not exists
			log.Printf("Initializing rate for %s/%s from API...", fromCurr, targetCurrency)
			s.FetchAndStoreRates(ctx) // Fallback to original fetch
			return
		} else if err != nil {
			log.Printf("Error checking rate for %s: %v", fromCurr, err)
			continue
		}

		// 2. Fluctuate
		currentRate, _ := decimal.NewFromString(currentRateStr)
		
		// Random noise between -0.05% and +0.05%
		// (rand - 0.5) * 0.001 => range -0.0005 to 0.0005
		noiseFactor := (rand.Float64() - 0.5) * 0.001 
		change := currentRate.Mul(decimal.NewFromFloat(noiseFactor))
		newMidRate := currentRate.Add(change)

		// Apply Fair Logic (Spread)
		spread := decimal.NewFromFloat(0.002) // 0.2%
		providerRate := newMidRate.Mul(decimal.NewFromInt(1).Sub(spread))

		if err := s.persistRate(ctx, fromCurr, targetCurrency, newMidRate, providerRate, spread); err != nil {
			log.Printf("Error persisting simulated rate for %s: %v", fromCurr, err)
		} else {
			log.Printf("Simulated update %s/%s: Mid=%s (%.4f%%)", 
				fromCurr, targetCurrency, newMidRate.StringFixed(4), noiseFactor*100)
		}
	}
}

// FetchAndStoreRates fetches real rates (Fallback/Init).
func (s *FXService) FetchAndStoreRates(ctx context.Context) {
	currencies := []string{"EUR", "USD", "RUB", "INR", "AUD"}
	targetCurrency := "THB"

	for _, fromCurr := range currencies {
		rate, err := s.fetchRateFromAPI(fromCurr, targetCurrency)
		if err != nil {
			log.Printf("Error fetching rate for %s/%s: %v", fromCurr, targetCurrency, err)
			continue
		}

		midRate := decimal.NewFromFloat(rate)
		spread := decimal.NewFromFloat(0.002)
		providerRate := midRate.Mul(decimal.NewFromInt(1).Sub(spread))

		if err := s.persistRate(ctx, fromCurr, targetCurrency, midRate, providerRate, spread); err != nil {
			log.Printf("Error persisting rate for %s/%s: %v", fromCurr, targetCurrency, err)
		} else {
			log.Printf("Updated rate %s/%s: Mid=%s, Prov=%s", fromCurr, targetCurrency, midRate.StringFixed(4), providerRate.StringFixed(4))
		}
	}
}

func (s *FXService) fetchRateFromAPI(base, target string) (float64, error) {
	// Using open.er-api.com (free, reliable for demo)
	url := fmt.Sprintf("https://open.er-api.com/v6/latest/%s", base)

	resp, err := http.Get(url)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("API returned status: %d", resp.StatusCode)
	}

	var data ExchangeRateAPIResponse
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return 0, err
	}

	rate, ok := data.Rates[target]
	if !ok {
		return 0, fmt.Errorf("rate for %s not found in response for base %s", target, base)
	}

	return rate, nil
}

func (s *FXService) persistRate(ctx context.Context, from, to string, mid, provider, spread decimal.Decimal) error {
	// Simple upsert into exchange_rates
	query := `
		INSERT INTO exchange_rates (from_currency, to_currency, mid_rate, provider_rate, spread, updated_at)
		VALUES ($1, $2, $3, $4, $5, NOW())
		ON CONFLICT (from_currency, to_currency) 
		DO UPDATE SET 
			mid_rate = EXCLUDED.mid_rate,
			provider_rate = EXCLUDED.provider_rate,
			spread = EXCLUDED.spread,
			updated_at = NOW();
	`
	_, err := s.DB.ExecContext(ctx, query, from, to, mid, provider, spread)
	if err != nil {
		return fmt.Errorf("failed to upsert exchange_rates: %w", err)
	}

	return nil
}

// ConvertToBase converts an amount in a given currency to THB (Base).
// Returns (baseAmount, usedRate, error)
func (s *FXService) ConvertToBase(ctx context.Context, amount int64, currency string) (int64, decimal.Decimal, error) {
	if currency == "THB" {
		return amount, decimal.NewFromInt(1), nil
	}

	// Stateless Query Logic: Bypassing Prepared Statements for PGBouncer Compatibility
	// We interpolate manually to force Simple Protocol.
	var rateStr string
	safeCurrency := strings.ReplaceAll(strings.ToUpper(currency), "'", "''")
	convQuery := fmt.Sprintf("SELECT provider_rate FROM exchange_rates WHERE from_currency = '%s' AND to_currency = 'THB'", safeCurrency)
	
	err := s.DB.QueryRowContext(ctx, convQuery).Scan(&rateStr)

	if err != nil {
		// FALLBACK: In production, we might want to fail hard or alert.
		// For now, if DB has no rate, we can't convert.
		return 0, decimal.Zero, fmt.Errorf("no exchange rate found for %s/THB: %w", currency, err)
	}

	rate, err := decimal.NewFromString(rateStr)
	if err != nil {
		return 0, decimal.Zero, fmt.Errorf("invalid decimal in DB: %w", err)
	}

	// Calculation: Amount * Rate
	// Amount is in minor units (e.g. cents). Rate is unit/unit.
	// Example: 100 EUR (1.00) * 40 => 4000 THB (40.00).
	// Minor units are usually preserved if decimals match.
	// Assuming both are 2 decimals or consistent.
	// If currencies have different decimals (e.g. JPY vs USD), this logic needs 'exponents' table.
	// For this task, assuming standardized 2 decimals or mapped minor units.

	amountDec := decimal.NewFromInt(amount)
	baseAmountDec := amountDec.Mul(rate)

	return baseAmountDec.IntPart(), rate, nil
}
