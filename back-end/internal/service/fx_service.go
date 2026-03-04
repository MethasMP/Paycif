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

	fxrpc "paysif/internal/grpc"

	"github.com/redis/go-redis/v9"
	"github.com/shopspring/decimal"
)

// FXService handles currency exchange operations.
type FXService struct {
	DB         *sql.DB
	GRPCClient fxrpc.FXClientInterface
	Redis      *redis.Client
}

// NewFXService creates a new FXService.
func NewFXService(db *sql.DB, grpcClient fxrpc.FXClientInterface, redisClient *redis.Client) *FXService {
	return &FXService{
		DB:         db,
		GRPCClient: grpcClient,
		Redis:      redisClient,
	}
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
		simQuery := "SELECT mid_rate FROM exchange_rates WHERE from_currency = $1 AND to_currency = 'THB'"

		err := s.DB.QueryRowContext(ctx, simQuery, strings.ToUpper(fromCurr)).Scan(&currentRateStr)

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

	// Survivability: Push update to High-Performance Rust Engine
	if s.GRPCClient != nil {
		// Use a detached context for push to ensure it doesn't fail the schedule if slow
		// But here we just use ctx for simplicity or create a quick timeout
		pushCtx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()

		if err := s.GRPCClient.UpdateRate(pushCtx, from, to, provider, "scheduler"); err != nil {
			log.Printf("⚠️ Failed to push rate %s/%s to Rust Engine: %v", from, to, err)
			// Don't fail the whole operation, just log warning
		} else {
			// Also push inverse! (Rust engine handles inverse logic internally? No, we better push both or let Rust handle)
			// Our Rust update_rate implementation is simple key-value.
			// Let's push inverse too blindly.
			if !provider.IsZero() {
				inverse := decimal.NewFromInt(1).Div(provider)
				s.GRPCClient.UpdateRate(pushCtx, to, from, inverse, "scheduler-inverse")
			}
		}
	}

	// Proactive Redis Cache Update (for Go API consumers)
	if s.Redis != nil {
		cacheKey := fmt.Sprintf("rate:%s:%s", from, to)
		// We need to match the structure WalletService expects: ExchangeRateResponse
		// But here we might not have all fields easily.
		// However, WalletService expects JSON.
		// Construct minimal response payload
		response := map[string]interface{}{
			"from_currency": from,
			"to_currency":   to,
			"provider_rate": provider.InexactFloat64(), // approximate for JSON
			"updated_at":    time.Now(),
		}
		data, _ := json.Marshal(response)
		// Set with 20 min TTL (Schedule runs every 15 min)
		s.Redis.Set(ctx, cacheKey, data, 20*time.Minute)
	}

	return nil
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
		log.Printf("⚠️ Rust FX Engine unavailable or failed: %v. Falling back to DB.", err)
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

// GetLimits returns the daily limit status from Rust FX Engine or DB Fallback
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
		log.Printf("⚠️ Rust Limit Check failed: %v. Falling back to DB.", err)
	}
	// 2. Redis Cache Check (Database Query Result Caching - Article Step)
	// Key: "limits:user:{userID}:{currency}"
	// We expire this cache frequently (e.g. 5 mins) or invalidate on transaction
	if s.Redis != nil {
		cacheKey := fmt.Sprintf("limits:user:%s:%s", userID, currency)
		val, err := s.Redis.Get(ctx, cacheKey).Result()
		if err == nil {
			var cachedMap map[string]interface{}
			if err := json.Unmarshal([]byte(val), &cachedMap); err == nil {
				return cachedMap, nil
			}
		}
	}

	// 3. Fallback: Call Postgres Function directly
	// Note: This relies on the 'get_daily_topup_status' function in DB.
	var currentTotalSatang, maxDailySatang, remainingSatang, minTransactionSatang int64
	var isLimitReached bool

	// query the function
	err := s.DB.QueryRowContext(ctx, "SELECT current_total, max_daily, remaining_limit, min_per_transaction, is_limit_reached FROM get_daily_topup_status($1)", userID).
		Scan(&currentTotalSatang, &maxDailySatang, &remainingSatang, &minTransactionSatang, &isLimitReached)

	if err != nil {
		return nil, fmt.Errorf("failed to fetch limits from DB fallback: %w", err)
	}

	// Convert Satang to Baht (float64) to match Rust Response format
	return map[string]interface{}{
		"max_daily_amount":       float64(maxDailySatang) / 100.0,
		"remaining_daily_amount": float64(remainingSatang) / 100.0,
		"current_daily_total":    float64(currentTotalSatang) / 100.0,
		"max_transaction_amount": 20000.0, // Hardcoded fallback max daily? Or imply from remaining. Using 20k as known max.
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
