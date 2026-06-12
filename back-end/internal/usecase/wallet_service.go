package usecase

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

	"paysif/internal/domain/entities"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/sony/gobreaker"
)

const (
	MaxTransactionAmount = 500000 // ฿5,000.00
	MinTransactionAmount = 50000  // ฿500.00
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

// ProcessPayment records a pay-per-use transaction from an external Alchemy Pay charge.
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
		fmt.Sprintf(`{"provider": "alchemypay", "merchant": "%s", "amount": %f}`, merchant, amount))
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

// isSerializationFailure reports whether err is a Postgres serialization
// failure (SQLSTATE 40001), which is retryable under SERIALIZABLE isolation.
func isSerializationFailure(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "40001"
}

// payoutReservation holds the result of the fast reservation transaction (Phase 1).
type payoutReservation struct {
	TransactionID  uuid.UUID
	SenderFullName string
	NewBalance     int64
}

// PayoutToPromptPay processes a PromptPay payout.
// It uses "Reject Before Debit" semantics: funds are tentatively reserved in a
// short SERIALIZABLE transaction (Phase 1), SQRIL is called OUTSIDE the DB
// transaction/lock (Phase 2), and the reservation is then finalized or rolled
// back in a second short transaction (Phase 3). This avoids holding a row
// lock and a pooled DB connection for the duration of the external HTTP call.
func (s *WalletService) PayoutToPromptPay(ctx context.Context, req PayoutRequest) (*PayoutResponse, error) {
	if req.Amount <= 0 {
		return nil, errors.New("amount must be positive")
	}
	if req.Amount > MaxTransactionAmount {
		return nil, fmt.Errorf("amount exceeds single transaction limit of %.2f", float64(MaxTransactionAmount)/100)
	}

	// 🛡️ Pre-flight Check: Circuit Breaker State (Yonisomanasikara L0 gate)
	if s.cb.State() == gobreaker.StateOpen {
		return nil, errors.New("payment provider is temporarily unavailable (circuit breaker open)")
	}

	// Phase 1: Reserve funds in a short-lived SERIALIZABLE transaction.
	// Retry on serialization failures (pg error 40001), which SERIALIZABLE
	// isolation can raise under concurrent access to the same profile row.
	var reservation *payoutReservation
	var alreadyProcessed *PayoutResponse
	var err error
	for attempt := 0; attempt < 3; attempt++ {
		reservation, alreadyProcessed, err = s.reservePayout(ctx, req)
		if !isSerializationFailure(err) {
			break
		}
		time.Sleep(time.Duration(attempt+1) * 50 * time.Millisecond)
	}
	if err != nil {
		return nil, err
	}
	if alreadyProcessed != nil {
		return alreadyProcessed, nil
	}

	// Phase 2: Call SQRIL OUTSIDE the DB transaction/lock.
	cbResult, cbErr := s.cb.Execute(func() (interface{}, error) {
		httpCtx, cancel := context.WithTimeout(ctx, 15*time.Second)
		defer cancel()
		return s.PaymentEngine.ExecutePayout(httpCtx, "", req.Amount, "THB", req.PromptPayID, req.RecipientName, req.IdempotencyKey, req.SqrilTxID, "cust_paycif_"+req.UserID.String())
	})

	if cbErr != nil {
		log.Printf("⚠️ PaymentEngine payout call failed: %v", cbErr)
		// SQRIL FAILED. Release the reservation so the funds become available again.
		if relErr := s.releasePayoutReservation(context.Background(), reservation.TransactionID); relErr != nil {
			log.Printf("🚨 CRITICAL: Failed to release payout reservation %s after SQRIL failure: %v", reservation.TransactionID, relErr)
		}
		return nil, fmt.Errorf("payout execution failed: %w", cbErr)
	}

	payoutResult := cbResult.(*PayoutResult)
	finalStatus := payoutResult.Status
	externalID := payoutResult.ExternalID

	// Phase 3: Finalize the reservation with the provider's result.
	if err := s.finalizePayoutReservation(ctx, reservation.TransactionID, finalStatus, externalID, req); err != nil {
		// Edge case: SQRIL paid the merchant, but we failed to finalize the DB record.
		log.Printf("🚨 CRITICAL: SQRIL payout %s succeeded but finalizing the DB record failed! User %s reservation %s: %v", externalID, req.UserID, reservation.TransactionID, err)
		return nil, fmt.Errorf("payout succeeded but database update failed: %w", err)
	}

	return &PayoutResponse{
		TransactionID: reservation.TransactionID.String(),
		Status:        finalStatus,
		Message:       fmt.Sprintf("Payout processed: %s", finalStatus),
		SenderName:    reservation.SenderFullName,
		NewBalance:    reservation.NewBalance,
	}, nil
}

// reservePayout validates the request and, if all checks pass, atomically
// inserts a PENDING transaction + debiting ledger entry that reserves the
// funds. Returns (nil reservation, non-nil response, nil err) if the
// idempotency key was already processed/in-flight.
func (s *WalletService) reservePayout(ctx context.Context, req PayoutRequest) (*payoutReservation, *PayoutResponse, error) {
	tx, err := s.DB.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelSerializable})
	if err != nil {
		return nil, nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// 1. Lock profile row (Mutex for this specific user's wallet)
	var senderFullName string
	err = tx.QueryRowContext(ctx, `
		SELECT full_name FROM profiles WHERE id = $1 FOR UPDATE
	`, req.UserID).Scan(&senderFullName)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil, errors.New("profile not found")
		}
		return nil, nil, fmt.Errorf("failed to fetch profile: %w", err)
	}

	// 2. Check Idempotency (has this payout already been completed or is it in-flight?)
	var existingID uuid.UUID
	var existingStatus string
	err = tx.QueryRowContext(ctx, "SELECT id, settlement_status FROM transactions WHERE reference_id = $1", req.IdempotencyKey).Scan(&existingID, &existingStatus)
	if err == nil {
		if existingStatus == "PENDING" {
			return nil, nil, fmt.Errorf("a payout for this reference is already in progress, please retry shortly")
		}
		return nil, &PayoutResponse{
			TransactionID: existingID.String(),
			Status:        "already_processed",
			Message:       "This payout was already processed",
			SenderName:    senderFullName,
			NewBalance:    0,
		}, nil
	} else if !errors.Is(err, sql.ErrNoRows) {
		return nil, nil, fmt.Errorf("error checking idempotency: %w", err)
	}

	// 4. Calculate actual balance
	var currentBalance int64
	err = tx.QueryRowContext(ctx, `
		SELECT COALESCE(SUM(amount), 0) FROM ledger_entries WHERE profile_id = $1
	`, req.UserID).Scan(&currentBalance)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to calculate current balance: %w", err)
	}

	// Enforce balance sufficiency
	if currentBalance < req.Amount {
		return nil, nil, fmt.Errorf("insufficient balance: %.2f THB available", float64(currentBalance)/100)
	}

	newBalance := currentBalance - req.Amount

	// 5. Reserve funds: insert PENDING transaction + debiting ledger entry.
	newTxID := uuid.New()
	description := fmt.Sprintf("PromptPay to %s (%s)", req.RecipientName, req.PromptPayID)
	metadata, err := json.Marshal(map[string]string{
		"promptpay_id":   req.PromptPayID,
		"recipient_name": req.RecipientName,
	})
	if err != nil {
		return nil, nil, fmt.Errorf("failed to encode metadata: %w", err)
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO transactions (id, reference_id, description, settlement_status, metadata, profile_id, amount, type, status)
		VALUES ($1, $2, $3, 'PENDING', $4, $5, $6, 'PAYOUT', 'PENDING')
	`, newTxID, req.IdempotencyKey, description, metadata, req.UserID, req.Amount)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to insert transaction: %w", err)
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO ledger_entries (id, transaction_id, profile_id, amount, balance_after, base_currency_amount, home_currency_amount)
		VALUES ($1, $2, $3, $4, $5, $4, $4)
	`, uuid.New(), newTxID, req.UserID, -req.Amount, newBalance)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create ledger entry: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, nil, fmt.Errorf("failed to commit reservation: %w", err)
	}

	return &payoutReservation{
		TransactionID:  newTxID,
		SenderFullName: senderFullName,
		NewBalance:     newBalance,
	}, nil, nil
}

// releasePayoutReservation removes a PENDING reservation (transaction + its
// ledger entry, via ON DELETE CASCADE) after SQRIL fails to execute the payout,
// restoring the reserved funds to the user's available balance.
func (s *WalletService) releasePayoutReservation(ctx context.Context, transactionID uuid.UUID) error {
	tx, err := s.DB.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to begin release transaction: %w", err)
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx, "DELETE FROM transactions WHERE id = $1 AND settlement_status = 'PENDING'", transactionID); err != nil {
		return fmt.Errorf("failed to delete reserved transaction: %w", err)
	}

	return tx.Commit()
}

// finalizePayoutReservation marks a PENDING reservation as settled with the
// provider's final status and metadata.
func (s *WalletService) finalizePayoutReservation(ctx context.Context, transactionID uuid.UUID, finalStatus, externalID string, req PayoutRequest) error {
	providerMetadata, err := json.Marshal(map[string]string{
		"sqril_tx_id": req.SqrilTxID,
		"external_id": externalID,
	})
	if err != nil {
		return fmt.Errorf("failed to encode provider metadata: %w", err)
	}

	_, err = s.DB.ExecContext(ctx, `
		UPDATE transactions
		SET settlement_status = $1, status = $1, provider_metadata = $2
		WHERE id = $3
	`, finalStatus, providerMetadata, transactionID)
	if err != nil {
		return fmt.Errorf("failed to finalize transaction: %w", err)
	}

	return nil
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
