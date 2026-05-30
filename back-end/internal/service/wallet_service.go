package service

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	"paysif/internal/models"

	"github.com/google/uuid"
	"github.com/sony/gobreaker"
)

const (
	MaxTransactionAmount  = 500000   // ฿5,000.00
	MaxDailyUserAmount    = 2000000  // ฿20,000.00
	MaxHourlySystemAmount = 10000000 // ฿100,000.00
)

// WalletService handles wallet operations.
type WalletService struct {
	DB             *sql.DB
	cb             *gobreaker.CircuitBreaker
	FX             *FXService
	Alert          *AlertService
	Audit          *AuditService
	PaymentEngine  *PaymentEngine
	localRateCache sync.Map
}

type localCacheItem struct {
	Response  *ExchangeRateResponse
	ExpiresAt time.Time
}

// NewWalletService creates a new instance of WalletService with Circuit Breaker.
func NewWalletService(db *sql.DB, fx *FXService, alert *AlertService, audit *AuditService, pe *PaymentEngine) *WalletService {
	cbSettings := gobreaker.Settings{
		Name:        "ExternalPaymentProvider",
		MaxRequests: 5,
		Interval:    60 * time.Second,
		Timeout:     30 * time.Second,
		ReadyToTrip: func(counts gobreaker.Counts) bool {
			failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
			return counts.Requests >= 3 && failureRatio >= 0.6
		},
	}
	return &WalletService{
		DB:            db,
		cb:            gobreaker.NewCircuitBreaker(cbSettings),
		FX:            fx,
		Alert:         alert,
		Audit:         audit,
		PaymentEngine: pe,
	}
}

// GetTransactions retrieves the transaction history for a specific profile (mapped to userID).
func (s *WalletService) GetTransactions(ctx context.Context, userID uuid.UUID) ([]models.TransactionHistoryDTO, error) {
	rows, err := s.DB.QueryContext(ctx, `
		SELECT l.id, l.profile_id, l.amount, t.description, l.created_at
		FROM ledger_entries l
		JOIN transactions t ON l.transaction_id = t.id
		WHERE l.profile_id = $1
		ORDER BY l.created_at DESC
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to query transactions: %w", err)
	}
	defer rows.Close()

	transactions := []models.TransactionHistoryDTO{}
	for rows.Next() {
		var dto models.TransactionHistoryDTO
		var amount int64
		if err := rows.Scan(&dto.ID, &dto.WalletID, &amount, &dto.Description, &dto.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan transaction: %w", err)
		}
		if amount < 0 {
			dto.Type = "DEBIT"
			dto.Amount = -amount
		} else {
			dto.Type = "CREDIT"
			dto.Amount = amount
		}
		transactions = append(transactions, dto)
	}
	return transactions, nil
}

// ExchangeRateResponse represents the rate data.
type ExchangeRateResponse struct {
	FromCurrency string    `json:"from_currency"`
	ToCurrency   string    `json:"to_currency"`
	ProviderRate float64   `json:"provider_rate"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// GetExchangeRate retrieves the latest rate for a currency pair.
func (s *WalletService) GetExchangeRate(ctx context.Context, fromCurr, toCurr string) (*ExchangeRateResponse, error) {
	cacheKey := fmt.Sprintf("rate:%s:%s", fromCurr, toCurr)

	if val, ok := s.localRateCache.Load(cacheKey); ok {
		item := val.(localCacheItem)
		if time.Now().Before(item.ExpiresAt) {
			return item.Response, nil
		}
		s.localRateCache.Delete(cacheKey)
	}

	var rate float64
	var updatedAt time.Time
	err := s.DB.QueryRowContext(ctx, "SELECT provider_rate, updated_at FROM exchange_rates WHERE from_currency = $1 AND to_currency = $2",
		strings.ToUpper(fromCurr), strings.ToUpper(toCurr)).Scan(&rate, &updatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, fmt.Errorf("rate not found for %s/%s", fromCurr, toCurr)
		}
		return nil, fmt.Errorf("failed to fetch rate: %w", err)
	}

	response := &ExchangeRateResponse{
		FromCurrency: fromCurr,
		ToCurrency:   toCurr,
		ProviderRate: rate,
		UpdatedAt:    updatedAt,
	}

	s.localRateCache.Store(cacheKey, localCacheItem{Response: response, ExpiresAt: time.Now().Add(10 * time.Second)})

	return response, nil
}

// ProcessPayment records a pay-per-use transaction from an external Stripe charge.
func (s *WalletService) ProcessPayment(ctx context.Context, userID uuid.UUID, amount float64, merchant string, referenceID string) error {
	tx, err := s.DB.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelSerializable})
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// 1. Idempotency check
	var exists bool
	err = tx.QueryRowContext(ctx, "SELECT EXISTS(SELECT 1 FROM transactions WHERE reference_id = $1)", referenceID).Scan(&exists)
	if err != nil {
		return err
	}
	if exists {
		log.Printf("ℹ[] Payment already processed for reference: %s", referenceID)
		return nil
	}

	// 2. Record Transaction
	newTxID := uuid.New()
	description := "Pay per use: " + merchant
	_, err = tx.ExecContext(ctx, `
		INSERT INTO transactions (id, profile_id, reference_id, amount, description, settlement_status, gateway_fee, provider_metadata, created_at)
		VALUES ($1, $2, $3, $4, $5, 'SETTLED', 0, $6, NOW())
	`, newTxID, userID, referenceID, int64(amount*100), description,
		fmt.Sprintf(`{"provider": "stripe", "merchant": "%s", "amount": %f}`, merchant, amount))
	if err != nil {
		return fmt.Errorf("failed to insert transaction: %w", err)
	}

	// 3. Create Ledger Entry
	_, err = tx.ExecContext(ctx, `
		INSERT INTO ledger_entries (id, transaction_id, profile_id, amount, balance_after, base_currency_amount, home_currency_amount, created_at)
		VALUES ($1, $2, $3, $4, 0, $4, $4, NOW())
	`, uuid.New(), newTxID, userID, int64(amount*100))
	if err != nil {
		return fmt.Errorf("failed to create ledger entry: %w", err)
	}

	// 4. Write to Outbox for async processing
	payloadStr := fmt.Sprintf(`{"transaction_id": "%s", "amount": %f, "user_id": "%s", "merchant": "%s"}`, newTxID, amount, userID, merchant)
	_, err = tx.ExecContext(ctx, `
		INSERT INTO transaction_outbox (id, transaction_id, event_type, payload, status, created_at)
		VALUES ($1, $2, 'PAYMENT_COMPLETED', $3, 'PENDING', NOW())
	`, uuid.New(), newTxID, payloadStr)
	if err != nil {
		return fmt.Errorf("failed to write to outbox: %w", err)
	}

	return tx.Commit()
}

// PayoutRequest represents a request to pay to an external PromptPay account.
type PayoutRequest struct {
	UserID         uuid.UUID
	Amount         int64
	PromptPayID    string
	RecipientName  string
	IdempotencyKey string
}

// PayoutResponse returned after a successful payout initiation.
type PayoutResponse struct {
	TransactionID string `json:"transaction_id"`
	Status        string `json:"status"`
	Message       string `json:"message"`
	SenderName    string `json:"sender_name"`
	NewBalance    int64  `json:"new_balance"`
}

// PayoutToPromptPay processes a PromptPay payout.
func (s *WalletService) PayoutToPromptPay(ctx context.Context, req PayoutRequest) (*PayoutResponse, error) {
	if req.Amount <= 0 {
		return nil, errors.New("amount must be positive")
	}
	if req.Amount > MaxTransactionAmount {
		return nil, fmt.Errorf("amount exceeds single transaction limit of %.2f", float64(MaxTransactionAmount)/100)
	}

	tx, err := s.DB.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelSerializable})
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Get Profile Name
	var senderFullName string
	err = tx.QueryRowContext(ctx, `
		SELECT full_name FROM profiles WHERE id = $1
	`, req.UserID).Scan(&senderFullName)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, errors.New("profile not found")
		}
		return nil, fmt.Errorf("failed to fetch profile: %w", err)
	}

	// Check Daily Limit (querying ledger_entries by profile_id)
	var dailyDebitTotal sql.NullInt64
	err = tx.QueryRowContext(ctx, `
		SELECT COALESCE(SUM(ABS(le.amount)), 0) FROM ledger_entries le
		JOIN transactions t ON le.transaction_id = t.id
		WHERE le.profile_id = $1 
		AND le.amount < 0 
		AND t.created_at > NOW() - INTERVAL '24 hours'
	`, req.UserID).Scan(&dailyDebitTotal)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return nil, fmt.Errorf("failed to check daily limit: %w", err)
	}
	if dailyDebitTotal.Valid && (dailyDebitTotal.Int64+req.Amount > MaxDailyUserAmount) {
		return nil, fmt.Errorf("daily payout limit of ฿%.2f exceeded", float64(MaxDailyUserAmount)/100)
	}

	// Idempotency Check
	var existingID uuid.UUID
	err = tx.QueryRowContext(ctx, "SELECT id FROM transactions WHERE reference_id = $1", req.IdempotencyKey).Scan(&existingID)
	if err == nil {
		return &PayoutResponse{
			TransactionID: existingID.String(),
			Status:        "already_processed",
			Message:       "This payout was already processed",
			SenderName:    senderFullName,
			NewBalance:    0,
		}, nil
	} else if !errors.Is(err, sql.ErrNoRows) {
		return nil, fmt.Errorf("error checking idempotency: %w", err)
	}

	// Create Transaction Record
	newTxID := uuid.New()
	description := fmt.Sprintf("PromptPay to %s (%s)", req.RecipientName, req.PromptPayID)
	metadata := fmt.Sprintf(`{"promptpay_id": "%s", "recipient_name": "%s"}`, req.PromptPayID, req.RecipientName)

	_, err = tx.ExecContext(ctx, `
		INSERT INTO transactions (id, reference_id, description, settlement_status, metadata, profile_id, amount, type, status)
		VALUES ($1, $2, $3, 'PENDING', $4, $5, $6, 'PAYOUT', 'PENDING')
	`, newTxID, req.IdempotencyKey, description, metadata, req.UserID, req.Amount)
	if err != nil {
		return nil, fmt.Errorf("failed to insert transaction: %w", err)
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO ledger_entries (id, transaction_id, profile_id, amount, balance_after, base_currency_amount, home_currency_amount)
		VALUES ($1, $2, $3, $4, 0, $4, $4)
	`, uuid.New(), newTxID, req.UserID, -req.Amount)
	if err != nil {
		return nil, fmt.Errorf("failed to create ledger entry: %w", err)
	}

	// Execute Payout via PaymentEngine
	payoutResult, pErr := s.PaymentEngine.ExecutePayout(ctx, "", req.Amount, "THB", req.PromptPayID, req.RecipientName, req.IdempotencyKey)
	finalStatus := "PENDING"
	externalID := ""
	if pErr == nil {
		finalStatus = payoutResult.Status
		externalID = payoutResult.ExternalID
	} else {
		log.Printf("⚠️ PaymentEngine payout call failed (will be retried by worker): %v", pErr)
	}

	// Queue for Payout Processing (Outbox Pattern)
	payloadObj := map[string]interface{}{
		"transaction_id": newTxID,
		"promptpay_id":   req.PromptPayID,
		"recipient_name": req.RecipientName,
		"amount":         req.Amount,
		"external_id":    externalID,
		"payout_status":  finalStatus,
	}
	payloadBytes, _ := json.Marshal(payloadObj)

	_, err = tx.ExecContext(ctx, `
		INSERT INTO transaction_outbox (id, transaction_id, event_type, payload, status)
		VALUES ($1, $2, 'PROMPTPAY_PAYOUT', $3, 'PENDING')
	`, uuid.New(), newTxID, string(payloadBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to queue payout outbox: %w", err)
	}

	if externalID != "" {
		_, _ = tx.ExecContext(ctx, `
			UPDATE transactions 
			SET provider_metadata = jsonb_set(provider_metadata, '{external_id}', $1),
			    settlement_status = $2
			WHERE id = $3
		`, fmt.Sprintf(`"%s"`, externalID), finalStatus, newTxID)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	return &PayoutResponse{
		TransactionID: newTxID.String(),
		Status:        finalStatus,
		Message:       "Payout initiated and recorded successfully",
		SenderName:    senderFullName,
		NewBalance:    0,
	}, nil
}

// EnsureUserAccount checks if a profile exists for the user, creating it if missing.
func (s *WalletService) EnsureUserAccount(ctx context.Context, userID uuid.UUID) error {
	username := "user_" + userID.String()[:8]
	_, err := s.DB.ExecContext(ctx, "INSERT INTO profiles (id, username, full_name) VALUES ($1, $2, 'Paysif User') ON CONFLICT (id) DO NOTHING", userID, username)
	if err != nil {
		return fmt.Errorf("failed to ensure profile: %w", err)
	}
	return nil
}
