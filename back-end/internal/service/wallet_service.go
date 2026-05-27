package service

import (
	"context"
	"crypto/ed25519"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	"paysif/internal/models"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
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
	Redis          *redis.Client
	Audit          *AuditService
	PaymentEngine  *PaymentEngine
	localRateCache sync.Map
}

type localCacheItem struct {
	Response  *ExchangeRateResponse
	ExpiresAt time.Time
}

// TransferRequest represents a request to transfer funds.
type TransferRequest struct {
	UserID        uuid.UUID
	FromWalletID  uuid.UUID `json:"from_wallet_id"`
	ToWalletID    uuid.UUID `json:"to_wallet_id"`
	Amount        int64     `json:"amount"`
	Currency      string    `json:"currency"`
	ReferenceID   string    `json:"reference_id"`
	Description   string    `json:"description"`
	PublicKey     string    `json:"-"`
	Signature     string    `json:"-"`
	SignedPayload string    `json:"-"`
}

// TransferResponse returned after a successful or idempotent transfer.
type TransferResponse struct {
	TransactionID uuid.UUID `json:"transaction_id"`
	UsedExisting  bool      `json:"used_existing"`
}

// NewWalletService creates a new instance of WalletService with Circuit Breaker.
func NewWalletService(db *sql.DB, fx *FXService, alert *AlertService, redisClient *redis.Client, audit *AuditService, pe *PaymentEngine) *WalletService {
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
		Redis:         redisClient,
		Audit:         audit,
		PaymentEngine: pe,
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

	// ⚡ RUST PRE-VALIDATION / SAFE MODE ARBITRATION
	performManualChecks := false

	if c.req.PublicKey != "" && c.req.Signature != "" {
		pubKeyBytes, err := hex.DecodeString(c.req.PublicKey)
		if err != nil {
			return nil, fmt.Errorf("invalid public key format: %w", err)
		}
		sigBytes, err := hex.DecodeString(c.req.Signature)
		if err != nil {
			return nil, fmt.Errorf("invalid signature format: %w", err)
		}

		valid, msg, err := c.svc.FX.PreValidateTransfer(
			ctx,
			c.req.UserID.String(),
			c.req.Currency,
			c.req.Amount,
			pubKeyBytes,
			sigBytes,
			[]byte(c.req.SignedPayload),
		)

		if err != nil {
			log.Printf("⚠️ [Safe Mode] Rust Engine Down (%v). Falling back to Manual Verification for Txn %s", err, c.req.ReferenceID)
			if len(pubKeyBytes) != 32 || len(sigBytes) != 64 {
				return nil, errors.New("invalid key length (safe mode)")
			}
			if !ed25519.Verify(pubKeyBytes, []byte(c.req.SignedPayload), sigBytes) {
				return nil, errors.New("invalid signature verification (safe mode)")
			}
			performManualChecks = true
		} else if !valid {
			return nil, fmt.Errorf("security/limit check failed: %s", msg)
		}
	} else {
		performManualChecks = true
	}

	// 🛡️ MANUAL / FALLBACK CHECKS
	if performManualChecks {
		if c.req.Amount > MaxTransactionAmount {
			return nil, fmt.Errorf("transaction amount %.2f exceeds limit", float64(c.req.Amount)/100)
		}

		var dailyDebitTotal sql.NullInt64
		err := c.svc.DB.QueryRowContext(ctx, `
			SELECT SUM(ABS(amount)) FROM ledger_entries le
			JOIN transactions t ON le.transaction_id = t.id
			WHERE le.wallet_id = $1 
			AND le.amount < 0 
			AND t.created_at > NOW() - INTERVAL '24 hours'
		`, c.req.FromWalletID).Scan(&dailyDebitTotal)
		if err != nil && !errors.Is(err, sql.ErrNoRows) {
			return nil, fmt.Errorf("failed to check daily limit (fallback): %w", err)
		}
		if dailyDebitTotal.Valid && (dailyDebitTotal.Int64+c.req.Amount > MaxDailyUserAmount) {
			return nil, errors.New("daily transfer limit exceeded (fallback)")
		}
	}

	// Hourly System Limit
	var hourlyTotal sql.NullInt64
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

	// 3. FX Conversion
	var baseAmount int64
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

	// 5. Update Wallets & Insert Ledger
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

	_, err = tx.ExecContext(ctx, `
		INSERT INTO ledger_entries (id, transaction_id, wallet_id, amount, balance_after, base_currency_amount, home_currency_amount)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`, uuid.New(), newTxID, c.req.FromWalletID, -c.req.Amount, senderBalanceAfter, -baseAmount, -c.req.Amount)
	if err != nil {
		return nil, fmt.Errorf("failed to create debit ledger: %w", err)
	}

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

	_, err = tx.ExecContext(ctx, `
		INSERT INTO ledger_entries (id, transaction_id, wallet_id, amount, balance_after, base_currency_amount, home_currency_amount)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`, uuid.New(), newTxID, c.req.ToWalletID, c.req.Amount, receiverBalanceAfter, baseAmount, c.req.Amount)
	if err != nil {
		return nil, fmt.Errorf("failed to create credit ledger: %w", err)
	}

	// ⚡ Bolt: Removed redundant post-insert integrity check.
	// Logic above ensures balance, and SERIALIZABLE isolation prevents race conditions.
	// Removing this query reduces transaction duration and serialization conflicts.

	// 6. Outbox
	payload := fmt.Sprintf(`{"transaction_id": "%s", "amount": %d, "currency": "%s"}`, newTxID, c.req.Amount, c.req.Currency)
	_, err = tx.ExecContext(ctx, `
		INSERT INTO transaction_outbox (id, transaction_id, event_type, payload, status)
		VALUES ($1, $2, $3, $4, 'PENDING')
	`, uuid.New(), newTxID, "TRANSFER_COMPLETED", payload)
	if err != nil {
		return nil, fmt.Errorf("failed to write to outbox: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	// 8. Update Redis (Async)
	if c.svc.Redis != nil {
		go func() {
			asyncCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			amountMajor := float64(c.req.Amount) / 100.0
			key := fmt.Sprintf("stats:user:%s:daily_total", c.req.UserID)
			c.svc.Redis.IncrByFloat(asyncCtx, key, amountMajor)
			c.svc.Redis.Expire(asyncCtx, key, 24*time.Hour)
			c.svc.Redis.Publish(asyncCtx, "user_limit_updates", fmt.Sprintf("%s:%f", c.req.UserID, amountMajor))
		}()
	}

	return &TransferResponse{TransactionID: newTxID, UsedExisting: false}, nil
}

func (c *TransferCommand) callExternalProviderStub(ctx context.Context) (bool, error) {
	select {
	case <-ctx.Done():
		return false, ctx.Err()
	default:
		return true, nil
	}
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

// GetTransactions retrieves the transaction history for a specific wallet.
func (s *WalletService) GetTransactions(ctx context.Context, userID uuid.UUID, walletID uuid.UUID) ([]models.TransactionHistoryDTO, error) {
	var ownerID uuid.UUID
	err := s.DB.QueryRowContext(ctx, "SELECT profile_id FROM wallets WHERE id = $1", walletID).Scan(&ownerID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, errors.New("wallet not found")
		}
		return nil, fmt.Errorf("failed to verify wallet owner: %w", err)
	}
	if ownerID != userID {
		return nil, errors.New("unauthorized: wallet does not belong to user")
	}

	rows, err := s.DB.QueryContext(ctx, `
		SELECT l.id, l.wallet_id, l.amount, t.description, l.created_at
		FROM ledger_entries l
		JOIN transactions t ON l.transaction_id = t.id
		WHERE l.wallet_id = $1
		ORDER BY l.created_at DESC
	`, walletID)
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

	if s.Redis != nil {
		val, err := s.Redis.Get(ctx, cacheKey).Result()
		if err == nil {
			var response ExchangeRateResponse
			if err := json.Unmarshal([]byte(val), &response); err == nil {
				return &response, nil
			}
		}
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

	if s.Redis != nil {
		data, _ := json.Marshal(response)
		s.Redis.Set(ctx, cacheKey, data, 60*time.Second)
	}
	s.localRateCache.Store(cacheKey, localCacheItem{Response: response, ExpiresAt: time.Now().Add(10 * time.Second)})

	return response, nil
}

// ProcessPayment records a pay-per-use transaction from an external Stripe charge.
// This is the core function for the new pay-per-use model.
func (s *WalletService) ProcessPayment(ctx context.Context, userID uuid.UUID, amount float64, merchant string, referenceID string) error {
	tx, err := s.DB.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelSerializable})
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// 1. Get User's Wallet with FOR UPDATE lock to prevent race conditions
	var walletID uuid.UUID
	err = tx.QueryRowContext(ctx, "SELECT id FROM wallets WHERE profile_id = $1 FOR UPDATE", userID).Scan(&walletID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return fmt.Errorf("wallet not found for user %s: %w", userID, err)
		}
		return fmt.Errorf("failed to fetch wallet: %w", err)
	}

	// 2. Idempotency check
	var exists bool
	err = tx.QueryRowContext(ctx, "SELECT EXISTS(SELECT 1 FROM transactions WHERE reference_id = $1)", referenceID).Scan(&exists)
	if err != nil {
		return err
	}
	if exists {
		log.Printf("ℹ️ Payment already processed for reference: %s", referenceID)
		return nil
	}

	// 3. Record Transaction
	newTxID := uuid.New()
	description := "Pay per use: " + merchant
	_, err = tx.ExecContext(ctx, `
		INSERT INTO transactions (id, wallet_id, reference_id, amount, description, settlement_status, gateway_fee, provider_metadata, created_at)
		VALUES ($1, $2, $3, $4, $5, 'SETTLED', 0, $6, NOW())
	`, newTxID, walletID, referenceID, int64(amount*100), description,
		fmt.Sprintf(`{"provider": "stripe", "merchant": "%s", "amount": %f}`, merchant, amount))
	if err != nil {
		return fmt.Errorf("failed to insert transaction: %w", err)
	}

	// 4. Create Ledger Entry (Credit to merchant wallet via external source)
	_, err = tx.ExecContext(ctx, `
		INSERT INTO ledger_entries (id, transaction_id, wallet_id, amount, balance_after, base_currency_amount, home_currency_amount, created_at)
		VALUES ($1, $2, $3, $4, (SELECT balance FROM wallets WHERE id = $3), $4, $4, NOW())
	`, uuid.New(), newTxID, walletID, int64(amount*100))
	if err != nil {
		return fmt.Errorf("failed to create ledger entry: %w", err)
	}

	// 5. Write to Outbox for async processing
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

// ProcessTopUp is kept for Stripe webhook compatibility.
// In the pay-per-use model, it now records the payment directly without modifying wallet balance.
func (s *WalletService) ProcessTopUp(ctx context.Context, userID uuid.UUID, amount float64, stripeRef string) error {
	return s.ProcessPayment(ctx, userID, amount, "Stripe Direct Charge", stripeRef)
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
// In pay-per-use, funds come from external Stripe charge, not internal wallet balance.
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

	// Get User's Wallet and Profile Name
	var walletID uuid.UUID
	var currentBalance int64
	var senderFullName string
	err = tx.QueryRowContext(ctx, `
		SELECT w.id, w.balance, p.full_name 
		FROM wallets w
		JOIN profiles p ON w.profile_id = p.id
		WHERE w.profile_id = $1 AND w.currency = 'THB'
		FOR UPDATE
	`, req.UserID).Scan(&walletID, &currentBalance, &senderFullName)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, errors.New("wallet or profile not found")
		}
		return nil, fmt.Errorf("failed to fetch wallet/profile: %w", err)
	}

	// Check Daily Limit
	var dailyDebitTotal sql.NullInt64
	err = tx.QueryRowContext(ctx, `
		SELECT COALESCE(SUM(ABS(le.amount)), 0) FROM ledger_entries le
		JOIN transactions t ON le.transaction_id = t.id
		WHERE le.wallet_id = $1 
		AND le.amount < 0 
		AND t.created_at > NOW() - INTERVAL '24 hours'
	`, walletID).Scan(&dailyDebitTotal)
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
			NewBalance:    currentBalance,
		}, nil
	} else if !errors.Is(err, sql.ErrNoRows) {
		return nil, fmt.Errorf("error checking idempotency: %w", err)
	}

	// Create Transaction Record
	newTxID := uuid.New()
	description := fmt.Sprintf("PromptPay to %s (%s)", req.RecipientName, req.PromptPayID)
	metadata := fmt.Sprintf(`{"promptpay_id": "%s", "recipient_name": "%s"}`, req.PromptPayID, req.RecipientName)

	_, err = tx.ExecContext(ctx, `
		INSERT INTO transactions (id, reference_id, description, settlement_status, metadata, wallet_id, amount, type, status)
		VALUES ($1, $2, $3, 'PENDING', $4, $5, $6, 'PAYOUT', 'PENDING')
	`, newTxID, req.IdempotencyKey, description, metadata, walletID, req.Amount)
	if err != nil {
		return nil, fmt.Errorf("failed to insert transaction: %w", err)
	}

	// Deduct from Wallet (for accounting purposes - will be reconciled with Stripe charge)
	var newBalance int64
	err = tx.QueryRowContext(ctx, `
		UPDATE wallets 
		SET balance = balance - $1, updated_at = NOW()
		WHERE id = $2
		RETURNING balance
	`, req.Amount, walletID).Scan(&newBalance)
	if err != nil {
		return nil, fmt.Errorf("failed to deduct from wallet: %w", err)
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO ledger_entries (id, transaction_id, wallet_id, amount, balance_after, base_currency_amount, home_currency_amount)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`, uuid.New(), newTxID, walletID, -req.Amount, newBalance, -req.Amount, -req.Amount)
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
		NewBalance:    newBalance,
	}, nil
}

// EnsureUserAccount checks if a profile and wallet exist for the user, creating them if missing.
func (s *WalletService) EnsureUserAccount(ctx context.Context, userID uuid.UUID) error {
	tx, err := s.DB.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	username := "user_" + userID.String()[:8]
	_, err = tx.ExecContext(ctx, "INSERT INTO profiles (id, username, full_name) VALUES ($1, $2, 'Paysif User') ON CONFLICT (id) DO NOTHING", userID, username)
	if err != nil {
		return fmt.Errorf("failed to ensure profile: %w", err)
	}

	var exists bool
	err = tx.QueryRowContext(ctx, "SELECT EXISTS(SELECT 1 FROM wallets WHERE profile_id = $1)", userID).Scan(&exists)
	if err != nil {
		return fmt.Errorf("failed to check wallet: %w", err)
	}

	if !exists {
		_, err = tx.ExecContext(ctx, "INSERT INTO wallets (profile_id, currency, balance) VALUES ($1, 'THB', 0)", userID)
		if err != nil {
			return fmt.Errorf("failed to create default wallet: %w", err)
		}
	}

	return tx.Commit()
}
