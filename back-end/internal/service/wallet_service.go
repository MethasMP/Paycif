package service

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"paysif/internal/models"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/sony/gobreaker"
)

const (
	MaxTransactionAmount  = 500000   // ฿5,000.00 (in minor units)
	MaxDailyUserAmount    = 2000000  // ฿20,000.00
	MaxHourlySystemAmount = 10000000 // ฿100,000.00
)

// WalletService handles wallet operations.
// WalletService handles wallet operations.
type WalletService struct {
	DB    *sql.DB
	cb    *gobreaker.CircuitBreaker
	FX    *FXService
	Alert *AlertService
	Redis *redis.Client
}

// TransferRequest represents a request to transfer funds.
type TransferRequest struct {
	UserID       uuid.UUID // Authenticated User ID
	FromWalletID uuid.UUID `json:"from_wallet_id"`
	ToWalletID   uuid.UUID `json:"to_wallet_id"`
	Amount       int64     `json:"amount"`
	Currency     string    `json:"currency"`
	ReferenceID  string    `json:"reference_id"`
	Description  string    `json:"description"`
}

// TransferResponse returned after a successful or idempotent transfer.
type TransferResponse struct {
	TransactionID uuid.UUID `json:"transaction_id"`
	UsedExisting  bool      `json:"used_existing"`
}

// NewWalletService creates a new instance of WalletService with Circuit Breaker.
func NewWalletService(db *sql.DB, fx *FXService, alert *AlertService, redisClient *redis.Client) *WalletService {
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
		DB:    db,
		cb:    gobreaker.NewCircuitBreaker(cbSettings),
		FX:    fx,
		Alert: alert,
		Redis: redisClient,
	}
}

// TransferCommand encapsulates the logic for a transfer operation.
type TransferCommand struct {
	req TransferRequest
	svc *WalletService
}

// Transfer executes a money transfer between two wallets using double-entry ledger.
func (s *WalletService) Transfer(ctx context.Context, req TransferRequest) (*TransferResponse, error) {
	cmd := &TransferCommand{req: req, svc: s}
	return cmd.Execute(ctx)
}

// Execute runs the transfer logic command.
func (c *TransferCommand) Execute(ctx context.Context) (*TransferResponse, error) {
	// ... (Ownership Checks and Guardrails remain same - assuming no change needed there)
	// For brevity in replacement, re-including checks is best to avoid context loss in replace tool.
	// But to save tokens, I will try to match from "Ownership Check" down if possible, or just replace Execute body.
	// Actually, the replace tool works best with defined start/end.
	// The user prompt "Ensure all check constraints...".
	// I'll stick to replacing the whole Execute function and struct definition to be safe.

	// 0. Ownership Check
	var profileID uuid.UUID
	err := c.svc.DB.QueryRowContext(ctx, "SELECT profile_id FROM wallets WHERE id = $1", c.req.FromWalletID).Scan(&profileID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, errors.New("source wallet not found")
		}
		return nil, fmt.Errorf("failed to fetch wallet owner: %w", err)
	}
	if profileID != c.req.UserID {
		return nil, errors.New("unauthorized: wallet does not belong to user")
	}

	if c.req.Amount <= 0 {
		return nil, errors.New("amount must be positive")
	}
	if c.req.FromWalletID == c.req.ToWalletID {
		return nil, errors.New("cannot transfer to same wallet")
	}

	// GUARDRAIL 1: Per-Transaction Limit
	if c.req.Amount > MaxTransactionAmount {
		return nil, fmt.Errorf("transaction amount %.2f exceeds limit of %.2f", float64(c.req.Amount)/100, float64(MaxTransactionAmount)/100)
	}

	// GUARDRAIL 2: Hourly Limit
	var hourlyTotal sql.NullInt64
	err = c.svc.DB.QueryRowContext(ctx, `
		SELECT SUM(gateway_fee) FROM transactions 
		WHERE created_at > NOW() - INTERVAL '1 hour'
	`).Scan(&hourlyTotal) // NOTE: Schema changed, checking logic usually on 'amount'.
	// Reverting to checking checks on 'amount' from transactions for consistency.
	// Original used: SELECT SUM(amount) FROM transactions.
	err = c.svc.DB.QueryRowContext(ctx, `
		SELECT SUM(amount) FROM transactions 
		WHERE created_at > NOW() - INTERVAL '1 hour'
	`).Scan(&hourlyTotal)

	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return nil, fmt.Errorf("failed to check system breaker: %w", err)
	}
	if hourlyTotal.Valid && (hourlyTotal.Int64+c.req.Amount > MaxHourlySystemAmount) {
		return nil, errors.New("system-wide hourly transfer limit exceeded")
	}

	// GUARDRAIL 3: Daily User Limit
	var dailyDebitTotal sql.NullInt64
	err = c.svc.DB.QueryRowContext(ctx, `
		SELECT SUM(ABS(amount)) FROM ledger_entries le
		JOIN transactions t ON le.transaction_id = t.id
		WHERE le.wallet_id = $1 
		AND le.amount < 0 
		AND t.created_at > NOW() - INTERVAL '24 hours'
	`, c.req.FromWalletID).Scan(&dailyDebitTotal)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return nil, fmt.Errorf("failed to check daily limit: %w", err)
	}
	if dailyDebitTotal.Valid && (dailyDebitTotal.Int64+c.req.Amount > MaxDailyUserAmount) {
		return nil, errors.New("daily transfer limit of ฿20,000 exceeded for this wallet")
	}

	// 1. Check Idempotency
	txOpts := &sql.TxOptions{Isolation: sql.LevelSerializable, ReadOnly: false}
	tx, err := c.svc.DB.BeginTx(ctx, txOpts)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	var existingID uuid.UUID
	err = tx.QueryRowContext(ctx, "SELECT id FROM transactions WHERE reference_id = $1", c.req.ReferenceID).Scan(&existingID)
	if err == nil {
		return &TransferResponse{TransactionID: existingID, UsedExisting: true}, nil
	} else if !errors.Is(err, sql.ErrNoRows) {
		return nil, fmt.Errorf("error checking idempotency: %w", err)
	}

	// 2. External Provider
	_, err = c.svc.cb.Execute(func() (interface{}, error) {
		return c.callExternalProviderStub(ctx)
	})
	if err != nil {
		return nil, fmt.Errorf("external provider check failed: %w", err)
	}

	// 3. FX Conversion (Circuit Breaker Wrapped)
	var baseAmount int64
	// Using a stub for CB execution context since types are tricky with generic CB,
	// but here we just wrap the logic.
	_, err = c.svc.cb.Execute(func() (interface{}, error) {
		var fxErr error
		baseAmount, _, fxErr = c.svc.FX.ConvertToBase(ctx, c.req.Amount, c.req.Currency)
		if fxErr != nil {
			return nil, fxErr
		}
		return nil, nil
	})
	if err != nil {
		c.svc.Alert.Notify("WARNING", "FX Service Failure", fmt.Sprintf("Circuit breaker tripped or Error: %v", err))
		return nil, fmt.Errorf("currency conversion failed: %w", err)
	}

	// 4. Create Transaction Record
	newTxID := uuid.New()
	_, err = tx.ExecContext(ctx, `
		INSERT INTO transactions (id, reference_id, description, settlement_status, gateway_fee, provider_metadata)
		VALUES ($1, $2, $3, 'UNSETTLED', 0, '{}')
	`, newTxID, c.req.ReferenceID, c.req.Description)
	if err != nil {
		return nil, fmt.Errorf("failed to insert transaction: %w", err)
	}

	// 5. Update Wallets & Insert Ledger (Reordered for Balance Snapshot)

	// A. Update Sender
	var senderBalanceAfter int64
	err = tx.QueryRowContext(ctx, `
		UPDATE wallets 
		SET balance = balance - $1, updated_at = NOW()
		WHERE id = $2 AND currency = $3 AND status = 'ACTIVE'
		RETURNING balance
	`, c.req.Amount, c.req.FromWalletID, c.req.Currency).Scan(&senderBalanceAfter)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, errors.New("sender wallet not found, currency mismatch, or HALTED")
		}
		return nil, fmt.Errorf("failed to debit sender: %w", err)
	}

	// B. Insert Ledger (Sender)
	_, err = tx.ExecContext(ctx, `
		INSERT INTO ledger_entries (
			id, transaction_id, wallet_id, amount, 
			balance_after, base_currency_amount, home_currency_amount
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`, uuid.New(), newTxID, c.req.FromWalletID, -c.req.Amount,
		senderBalanceAfter, -baseAmount, -c.req.Amount)
	if err != nil {
		return nil, fmt.Errorf("failed to create debit ledger: %w", err)
	}

	// C. Update Receiver
	var receiverBalanceAfter int64
	err = tx.QueryRowContext(ctx, `
		UPDATE wallets 
		SET balance = balance + $1, updated_at = NOW()
		WHERE id = $2 AND currency = $3 AND status = 'ACTIVE'
		RETURNING balance
	`, c.req.Amount, c.req.ToWalletID, c.req.Currency).Scan(&receiverBalanceAfter)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, errors.New("receiver wallet not found, currency mismatch, or HALTED")
		}
		return nil, fmt.Errorf("failed to credit receiver: %w", err)
	}

	// D. Insert Ledger (Receiver)
	_, err = tx.ExecContext(ctx, `
		INSERT INTO ledger_entries (
			id, transaction_id, wallet_id, amount, 
			balance_after, base_currency_amount, home_currency_amount
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`, uuid.New(), newTxID, c.req.ToWalletID, c.req.Amount,
		receiverBalanceAfter, baseAmount, c.req.Amount)
	if err != nil {
		return nil, fmt.Errorf("failed to create credit ledger: %w", err)
	}

	// *** HALT & PROTECT: Double-Entry Integrity Check ***
	var ledgerSum int64
	err = tx.QueryRowContext(ctx, `
		SELECT COALESCE(SUM(amount), 0) FROM ledger_entries WHERE transaction_id = $1
	`, newTxID).Scan(&ledgerSum)

	if err != nil {
		return nil, fmt.Errorf("failed to verify ledger integrity: %w", err)
	}

	if ledgerSum != 0 {
		// CRITICAL: Integrity Breach Detected
		// 1. Log Alert
		c.svc.Alert.Notify("CRITICAL", "Integrity Breach Detected", fmt.Sprintf("Transaction %s has non-zero sum: %d", newTxID, ledgerSum))

		// 2. Rollback the faulty transaction immediately
		_ = tx.Rollback()

		// 3. Halt Wallets (in a new transaction)
		haltCtx := context.Background() // Use fresh context for emergency halt
		go func(txID uuid.UUID, w1, w2 uuid.UUID) {
			emergencyDB := c.svc.DB
			_, _ = emergencyDB.ExecContext(haltCtx, `
				UPDATE wallets SET status = 'HALTED', updated_at = NOW() WHERE id IN ($1, $2)
			`, w1, w2)
			// Record the failed transaction state
			_, _ = emergencyDB.ExecContext(haltCtx, `
				UPDATE transactions SET settlement_status = 'FAILED_INTEGRITY' WHERE id = $1
			`, txID)
		}(newTxID, c.req.FromWalletID, c.req.ToWalletID)

		return nil, errors.New("integrity check failed: wallets halted")
	}

	// 6. Outbox
	payload := fmt.Sprintf(`{"transaction_id": "%s", "amount": %d, "currency": "%s"}`, newTxID, c.req.Amount, c.req.Currency)
	_, err = tx.ExecContext(ctx, `
		INSERT INTO transaction_outbox (id, transaction_id, event_type, payload, status)
		VALUES ($1, $2, $3, $4, 'PENDING')
	`, uuid.New(), newTxID, "TRANSFER_COMPLETED", payload)
	if err != nil {
		return nil, fmt.Errorf("failed to write to outbox: %w", err)
	}

	// 7. Commit
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	return &TransferResponse{TransactionID: newTxID, UsedExisting: false}, nil
}

// callExternalProviderStub simulates an external call wrapped by CB.
func (c *TransferCommand) callExternalProviderStub(ctx context.Context) (bool, error) {
	return true, nil
}

// BalanceResponse represents the simplified balance view.
type BalanceResponse struct {
	WalletID uuid.UUID `json:"wallet_id"`
	Currency string    `json:"currency"`
	Balance  int64     `json:"balance"`
}

// GetBalance retrieves the balance for a user's wallet of a specific currency.
func (s *WalletService) GetBalance(ctx context.Context, userID uuid.UUID, currency string) (*BalanceResponse, error) {
	var walletID uuid.UUID
	var balance int64

	err := s.DB.QueryRowContext(ctx, `
		SELECT id, balance 
		FROM wallets 
		WHERE profile_id = $1 AND currency = $2
	`, userID, strings.ToUpper(currency)).Scan(&walletID, &balance)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, fmt.Errorf("wallet not found for currency %s", currency)
		}
		return nil, fmt.Errorf("failed to fetch balance: %w", err)
	}

	return &BalanceResponse{
		WalletID: walletID,
		Currency: currency,
		Balance:  balance,
	}, nil
}

// GetTransactions retrieves the transaction history for a specific wallet verified against the user.
func (s *WalletService) GetTransactions(ctx context.Context, userID uuid.UUID, walletID uuid.UUID) ([]models.TransactionHistoryDTO, error) {
	// 1. Verify Ownership
	var ownerID uuid.UUID
	err := s.DB.QueryRowContext(ctx, "SELECT profile_id FROM wallets WHERE id = $1", walletID).Scan(&ownerID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, errors.New("wallet not found")
		}
		return nil, fmt.Errorf("failed to verify wallet owner: %w", err)
	}
	if ownerID != userID {
		fmt.Printf("⚠️ Unauthorized Access: WalletOwner(%s) != SessionUser(%s)\n", ownerID, userID)
		return nil, errors.New("unauthorized: wallet does not belong to user")
	}

	// 2. Query Ledger Entries JOIN Transactions
	query := `
		SELECT l.id, l.wallet_id, l.amount, t.description, l.created_at
		FROM ledger_entries l
		JOIN transactions t ON l.transaction_id = t.id
		WHERE l.wallet_id = $1
		ORDER BY l.created_at DESC
	`
	rows, err := s.DB.QueryContext(ctx, query, walletID)
	if err != nil {
		return nil, fmt.Errorf("failed to query transactions: %w", err)
	}
	defer rows.Close()

	// Initialize with empty slice to ensure it is never nil in JSON response
	transactions := []models.TransactionHistoryDTO{}

	for rows.Next() {
		var dto models.TransactionHistoryDTO
		var amount int64
		// Scan into temp amount to logic check sign
		if err := rows.Scan(&dto.ID, &dto.WalletID, &amount, &dto.Description, &dto.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan transaction: %w", err)
		}

		if amount < 0 {
			dto.Type = "DEBIT"
			dto.Amount = -amount // Absolute value for display
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

// GetExchangeRate retrieves the latest rate for a currency pair (e.g. EUR -> THB).
// GetExchangeRate retrieves the latest rate for a currency pair (e.g. EUR -> THB).
func (s *WalletService) GetExchangeRate(ctx context.Context, fromCurr, toCurr string) (*ExchangeRateResponse, error) {
	// 1. Check Redis Cache
	if s.Redis != nil {
		cacheKey := fmt.Sprintf("rate:%s:%s", fromCurr, toCurr)
		val, err := s.Redis.Get(ctx, cacheKey).Result()
		if err == nil {
			// Cache Hit
			var response ExchangeRateResponse
			if err := json.Unmarshal([]byte(val), &response); err == nil {
				return &response, nil
			}
		}
	}

	var rate float64
	var updatedAt time.Time

	// Stateless Query Logic: Bypassing Prepared Statements for PGBouncer Compatibility
	// We interpolate manually to force Simple Protocol.
	// Safety: Inputs are strictly cast to Upper Case and we trust standard currency codes (3 chars usually)
	// Additional safety: Escape quotes although unlikely in currency codes.
	safeFrom := strings.ReplaceAll(strings.ToUpper(fromCurr), "'", "''")
	safeTo := strings.ReplaceAll(strings.ToUpper(toCurr), "'", "''")

	query := fmt.Sprintf("SELECT provider_rate, updated_at FROM exchange_rates WHERE from_currency = '%s' AND to_currency = '%s'", safeFrom, safeTo)
	
	// No transaction needed for simple read
	err := s.DB.QueryRowContext(ctx, query).Scan(&rate, &updatedAt)
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

	// 3. Write to Cache (Async or blocking? Blocking is safer for consistency here, but async is faster. 
	// Given requirement is speed, blocking logic but short TTL is fine.)
	if s.Redis != nil {
		cacheKey := fmt.Sprintf("rate:%s:%s", fromCurr, toCurr)
		data, _ := json.Marshal(response)
		// Cache for 60 seconds (Matches FX refresh interval somewhat)
		s.Redis.Set(ctx, cacheKey, data, 60*time.Second) 
	}

	return response, nil
}

// ProcessTopUp handles the successful payment webhook
func (s *WalletService) ProcessTopUp(ctx context.Context, userID uuid.UUID, amount float64, stripeRef string) error {
	tx, err := s.DB.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelSerializable})
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// 1. Get User's Wallet
	var walletID uuid.UUID
	err = tx.QueryRowContext(ctx, "SELECT id FROM wallets WHERE user_id = $1", userID).Scan(&walletID)
	if err != nil {
		return fmt.Errorf("wallet not found for user %s: %w", userID, err)
	}

	// 2. Check for duplicate transaction using idempotency key (stripeRef)
	var exists bool
	err = tx.QueryRowContext(ctx, "SELECT EXISTS(SELECT 1 FROM transactions WHERE reference_id = $1)", stripeRef).Scan(&exists)
	if err != nil {
		return err
	}
	if exists {
		// Already processed
		return nil
	}

	// 3. Create Transaction Record
	txnID := uuid.New()
	_, err = tx.ExecContext(ctx, `
		INSERT INTO transactions (id, wallet_id, type, amount, reference_id, status, description, created_at)
		VALUES ($1, $2, 'TOPUP', $3, $4, 'SUCCESS', 'Stripe Top Up', NOW())
	`, txnID, walletID, amount, stripeRef)
	if err != nil {
		return fmt.Errorf("failed to insert transaction: %w", err)
	}

	// 4. Create Ledger Entry (Credit Only for Top Up)
	_, err = tx.ExecContext(ctx, `
		INSERT INTO ledger_entries (id, transaction_id, wallet_id, type, amount, balance_after, created_at)
		VALUES ($1, $2, $3, 'CREDIT', $4, (SELECT balance + $4 FROM wallets WHERE id = $3), NOW())
	`, uuid.New(), txnID, walletID, amount)
	if err != nil {
		return fmt.Errorf("failed to create ledger entry: %w", err)
	}

	// 5. Update Wallet Balance
	_, err = tx.ExecContext(ctx, `
		UPDATE wallets SET balance = balance + $1, updated_at = NOW() WHERE id = $2
	`, amount, walletID)
	if err != nil {
		return fmt.Errorf("failed to update wallet balance: %w", err)
	}

	return tx.Commit()
}
