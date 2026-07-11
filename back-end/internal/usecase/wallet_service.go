package usecase

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"sync"
	"time"

	"paysif/internal/domain/entities"
	"paysif/internal/infrastructure/logger"

	"github.com/google/uuid"
	"github.com/sony/gobreaker"
)



var (
	ErrLimitExceeded       = errors.New("kyc verification limit exceeded")
	ErrNetworkUnavailable  = errors.New("thai payment network is unavailable")
	ErrMerchantUnavailable = errors.New("merchant account is unavailable")
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
	cacheKey := "rate:" + fromCurr + ":" + toCurr

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

// ProcessPayment records a pay-per-use transaction from an external Alchemy Pay charge.
func (s *WalletService) ProcessPayment(ctx context.Context, userID uuid.UUID, amount float64, merchant string, referenceID string) error {
	tx, err := s.DB.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelSerializable})
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	// 1. Record Transaction with Atomic Idempotency
	newTxID := uuid.New()
	description := "Pay per use: " + merchant
	metadata := `{"provider": "alchemypay", "merchant": ` + strconv.Quote(merchant) + `, "amount": ` + strconv.FormatFloat(amount, 'f', 6, 64) + `}`

	result, err := tx.ExecContext(ctx, `
		INSERT INTO transactions (id, profile_id, reference_id, amount, description, settlement_status, gateway_fee, provider_metadata, created_at)
		VALUES ($1, $2, $3, $4, $5, 'SETTLED', 0, $6, NOW())
		ON CONFLICT (reference_id) DO NOTHING
	`, newTxID, userID, referenceID, int64(amount*100), description, metadata)
	if err != nil {
		return fmt.Errorf("failed to insert transaction: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		logger.WithContext(ctx).Info("Payment already processed (idempotent skip)", "reference_id", referenceID)
		return nil
	}

	// 2. Create Ledger Entry
	_, err = tx.ExecContext(ctx, `
		INSERT INTO ledger_entries (id, transaction_id, profile_id, amount, balance_after, base_currency_amount, home_currency_amount, created_at)
		VALUES ($1, $2, $3, $4, 0, $4, $4, NOW())
	`, uuid.New(), newTxID, userID, int64(amount*100))
	if err != nil {
		return fmt.Errorf("failed to create ledger entry: %w", err)
	}

	// 3. Write to Outbox for async processing
	payloadStr := `{"transaction_id": "` + newTxID.String() + `", "amount": ` + strconv.FormatFloat(amount, 'f', 6, 64) + `, "user_id": "` + userID.String() + `", "merchant": ` + strconv.Quote(merchant) + `}`
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
	SqrilTxID      string
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
// In the Async FIFO pattern, this function accepts the request, verifies basic inputs and limits,
// and immediately writes the payout event to the transaction_outbox in under 1ms with NO profile row locks
// or serialization checks. The balance check and actual fund deduction occur asynchronously in FIFO order
// within the background worker.
func (s *WalletService) PayoutToPromptPay(ctx context.Context, req PayoutRequest) (*PayoutResponse, error) {
	if req.Amount <= 0 {
		return nil, errors.New("amount must be positive")
	}
	// 🛡️ Strict limits enforcement via FX Engine (No Yes-Man Fallback)
	limits, err := s.FX.GetLimits(ctx, req.UserID.String(), "THB")
	if err != nil {
		return nil, fmt.Errorf("%w: unable to fetch dynamic transaction limits", ErrLimitExceeded)
	}

	maxTxAmountFloat, ok := limits["max_transaction_amount"].(float64)
	if !ok || maxTxAmountFloat <= 0 {
		return nil, fmt.Errorf("%w: invalid limit configuration received from engine", ErrLimitExceeded)
	}

	maxTxAmountSatang := int64(maxTxAmountFloat * 100)
	minTxAmountSatang := int64(500 * 100) // Business requirement minimum

	if req.Amount < minTxAmountSatang {
		return nil, fmt.Errorf("amount must be at least 500.00 THB")
	}

	if req.Amount > maxTxAmountSatang {
		return nil, fmt.Errorf("%w: amount exceeds single transaction limit of %.2f", ErrLimitExceeded, maxTxAmountFloat)
	}

	// 🛡️ Pre-flight Check: Circuit Breaker State (Yonisomanasikara L0 gate)
	if s.cb.State() == gobreaker.StateOpen {
		return nil, fmt.Errorf("%w: payment provider is temporarily unavailable (circuit breaker open)", ErrNetworkUnavailable)
	}

	// Get the user's full name without any row lock
	var senderFullName string
	err = s.DB.QueryRowContext(ctx, "SELECT full_name FROM profiles WHERE id = $1", req.UserID).Scan(&senderFullName)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, errors.New("profile not found")
		}
		return nil, fmt.Errorf("failed to fetch profile: %w", err)
	}

	newTxID := uuid.New()
	description := "PromptPay to " + req.RecipientName + " (" + req.PromptPayID + ")"
	metadata, err := json.Marshal(map[string]string{
		"promptpay_id":   req.PromptPayID,
		"recipient_name": req.RecipientName,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to encode metadata: %w", err)
	}

	payoutPayload, err := json.Marshal(map[string]interface{}{
		"transaction_id": newTxID.String(),
		"promptpay_id":   req.PromptPayID,
		"recipient_name": req.RecipientName,
		"amount":         req.Amount,
		"sqril_tx_id":    req.SqrilTxID,
		"customer_id":    "cust_paycif_" + req.UserID.String(),
		"user_id":        req.UserID.String(),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to marshal outbox payload: %w", err)
	}

	tx, err := s.DB.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to start write transaction: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	// Check Idempotency (has this payout already been completed or is it in-flight?)
	var existingID uuid.UUID
	var existingStatus string
	err = tx.QueryRowContext(ctx, "SELECT id, settlement_status FROM transactions WHERE reference_id = $1", req.IdempotencyKey).Scan(&existingID, &existingStatus)
	if err == nil {
		if existingStatus == "PENDING" {
			return nil, fmt.Errorf("a payout for this reference is already in progress, please retry shortly")
		}
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

	_, err = tx.ExecContext(ctx, `
		INSERT INTO transactions (id, reference_id, description, settlement_status, metadata, profile_id, amount, type, status)
		VALUES ($1, $2, $3, 'PENDING', $4, $5, $6, 'PAYOUT', 'PENDING')
	`, newTxID, req.IdempotencyKey, description, metadata, req.UserID, req.Amount)
	if err != nil {
		return nil, fmt.Errorf("failed to insert transaction: %w", err)
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO transaction_outbox (id, transaction_id, event_type, payload, status, created_at)
		VALUES ($1, $2, 'PAYOUT_REQUESTED', $3, 'PENDING', NOW())
	`, uuid.New(), newTxID, string(payoutPayload))
	if err != nil {
		return nil, fmt.Errorf("failed to insert outbox event: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit outbox write: %w", err)
	}

	return &PayoutResponse{
		TransactionID: newTxID.String(),
		Status:        "PENDING",
		Message:       "Payout queued for execution",
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

// PayoutIntent represents an on-ramp and payout combination.
type PayoutIntent struct {
	ID            uuid.UUID
	UserID        uuid.UUID
	Amount        int64
	PromptPayID   string
	RecipientName string
	SqrilTxID     string
	Status        string
}

// CreatePayoutIntent stores an intent in DB.
func (s *WalletService) CreatePayoutIntent(ctx context.Context, intent PayoutIntent) error {
	_, err := s.DB.ExecContext(ctx, `
		INSERT INTO payout_intents (id, user_id, amount, promptpay_id, recipient_name, sqril_tx_id, status, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
	`, intent.ID, intent.UserID, intent.Amount, intent.PromptPayID, intent.RecipientName, intent.SqrilTxID, "PENDING")
	return err
}

// GetPayoutIntent retrieves the intent details.
func (s *WalletService) GetPayoutIntent(ctx context.Context, id uuid.UUID) (*PayoutIntent, error) {
	var intent PayoutIntent
	err := s.DB.QueryRowContext(ctx, `
		SELECT id, user_id, amount, promptpay_id, recipient_name, sqril_tx_id, status 
		FROM payout_intents WHERE id = $1
	`, id).Scan(&intent.ID, &intent.UserID, &intent.Amount, &intent.PromptPayID, &intent.RecipientName, &intent.SqrilTxID, &intent.Status)
	if err != nil {
		return nil, err
	}
	return &intent, nil
}

// UpdatePayoutIntentStatus updates the status.
func (s *WalletService) UpdatePayoutIntentStatus(ctx context.Context, id uuid.UUID, status string) error {
	_, err := s.DB.ExecContext(ctx, "UPDATE payout_intents SET status = $1 WHERE id = $2", status, id)
	return err
}
