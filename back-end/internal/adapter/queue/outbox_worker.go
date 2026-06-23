package queue

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	"paysif/internal/usecase"

	"github.com/google/uuid"
)

// OutboxWorker processes pending events from the transaction_outbox.
type OutboxWorker struct {
	DB            *sql.DB
	PaymentEngine *usecase.PaymentEngine
	wg            sync.WaitGroup
}

// NewOutboxWorker creates a new worker instance.
func NewOutboxWorker(db *sql.DB, pe *usecase.PaymentEngine) *OutboxWorker {
	return &OutboxWorker{
		DB:            db,
		PaymentEngine: pe,
	}
}

// runPruner periodically deletes processed outbox entries to prevent table bloat.
func (w *OutboxWorker) runPruner(ctx context.Context) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	log.Println("Outbox pruner routine started...")
	for {
		select {
		case <-ctx.Done():
			log.Println("Outbox pruner stopping...")
			return
		case <-ticker.C:
			res, err := w.DB.ExecContext(ctx, `
				DELETE FROM transaction_outbox 
				WHERE status = 'PROCESSED' 
				AND processed_at < NOW() - INTERVAL '1 minute'
			`)
			if err != nil {
				log.Printf("⚠️ Failed to prune processed outbox events: %v", err)
			} else {
				rows, _ := res.RowsAffected()
				if rows > 0 {
					log.Printf("🧹 Outbox Pruner: Deleted %d processed event rows older than 1 minute", rows)
				}
			}
		}
	}
}

// Run starts the worker loop.
func (w *OutboxWorker) Run(ctx context.Context) {
	ticker := time.NewTicker(50 * time.Millisecond)
	defer ticker.Stop()

	go w.runPruner(ctx)

	log.Println("Resilient Outbox worker started...")

	for {
		select {
		case <-ctx.Done():
			log.Println("Outbox worker stopping, waiting for active batch to finish...")
			w.wg.Wait()
			log.Println("All active events processed. Outbox worker stopped.")
			return
		case <-ticker.C:
			w.wg.Add(1)
			if err := w.processBatch(ctx); err != nil {
				log.Printf("Error processing batch: %v", err)
			}
			w.wg.Done()
		}
	}
}

type eventItem struct {
	id        string
	eventType string
	payload   []byte
	retry     int
}

func (w *OutboxWorker) processBatch(ctx context.Context) error {
	// Phase 1: Start a short transaction to claim and lock rows (Avoid holding locks during HTTP calls)
	tx, err := w.DB.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to begin batch transaction: %w", err)
	}
	defer tx.Rollback()

	rows, err := tx.QueryContext(ctx, `
		SELECT id, event_type, payload, retry_count
		FROM transaction_outbox 
		WHERE status IN ('PENDING', 'RETRY_PENDING')
		AND (last_attempt_at IS NULL OR last_attempt_at < NOW() - (POWER(2, retry_count) * INTERVAL '5 seconds'))
		ORDER BY created_at ASC 
		LIMIT 10 
		FOR UPDATE SKIP LOCKED
	`)
	if err != nil {
		return fmt.Errorf("failed to query pending events: %w", err)
	}
	defer rows.Close()

	var events []eventItem
	for rows.Next() {
		var item eventItem
		if err := rows.Scan(&item.id, &item.eventType, &item.payload, &item.retry); err != nil {
			log.Printf("Failed to scan row: %v", err)
			continue
		}
		events = append(events, item)
	}
	rows.Close()

	if len(events) == 0 {
		return nil
	}

	// Mark events as PROCESSING and release locks immediately
	for _, event := range events {
		_, err = tx.ExecContext(ctx, `
			UPDATE transaction_outbox 
			SET status = 'PROCESSING', last_attempt_at = NOW(), retry_count = retry_count + 1
			WHERE id = $1
		`, event.id)
		if err != nil {
			return fmt.Errorf("failed to update event status to processing: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit batch claim transaction: %w", err)
	}

	// Phase 2: Process events outside DB transaction (No long locks!)
	for _, event := range events {
		log.Printf("Processing event %s | Type: %s | Attempt: %d", event.id, event.eventType, event.retry+1)

		err := w.handleEvent(ctx, event.id, event.eventType, event.payload)

		// Phase 3: Record result in short separate transactions
		updateTx, upErr := w.DB.BeginTx(ctx, nil)
		if upErr != nil {
			log.Printf("⚠️ Failed to start update transaction for event %s: %v", event.id, upErr)
			continue
		}

		if err == nil {
			_, _ = updateTx.ExecContext(ctx, `
				UPDATE transaction_outbox 
				SET status = 'PROCESSED', processed_at = NOW()
				WHERE id = $1
			`, event.id)
		} else {
			log.Printf("Event %s failed: %v", event.id, err)
			w.handleFailureInTx(updateTx, event.id, event.retry, err)
		}
		_ = updateTx.Commit()
	}

	return nil
}

func (w *OutboxWorker) handleEvent(ctx context.Context, outboxID string, eventType string, payload []byte) error {
	switch eventType {
	case "PROMPTPAY_PAYOUT", "PAYOUT_REQUESTED":
		return w.processPromptPayPayout(ctx, outboxID, payload)
	case "TRANSFER_COMPLETED":
		log.Printf("Transfer completed for event %s, no further action needed.", outboxID)
		return nil
	default:
		log.Printf("Unknown event type: %s", eventType)
		return nil
	}
}

func (w *OutboxWorker) processPromptPayPayout(ctx context.Context, idempotencyKey string, payload []byte) error {
	var data struct {
		TransactionID string `json:"transaction_id"`
		PromptPayID   string `json:"promptpay_id"`
		RecipientName string `json:"recipient_name"`
		Amount        int64  `json:"amount"`
		SqrilTxID     string `json:"sqril_tx_id"`
		CustomerID    string `json:"customer_id"`
		UserID        string `json:"user_id"`
	}

	if err := json.Unmarshal(payload, &data); err != nil {
		return fmt.Errorf("failed to unmarshal payout payload: %w", err)
	}

	txUUID, err := uuid.Parse(data.TransactionID)
	if err != nil {
		return fmt.Errorf("invalid transaction uuid: %w", err)
	}
	userUUID, err := uuid.Parse(data.UserID)
	if err != nil {
		return fmt.Errorf("invalid user uuid: %w", err)
	}

	// 1. Local State Check: Check if already completed
	var dbStatus string
	err = w.DB.QueryRowContext(ctx, "SELECT COALESCE(status, 'PENDING') FROM transactions WHERE id = $1", txUUID).Scan(&dbStatus)
	if err == nil && (dbStatus == "SUCCESS" || dbStatus == "SETTLED" || dbStatus == "COMPLETED") {
		log.Printf("ℹ️ Transaction %s already completed in DB. Skipping execution.", data.TransactionID)
		return nil
	}

	// 2. Perform balance deduction & check inside a serializable database transaction
	deductTx, err := w.DB.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelSerializable})
	if err != nil {
		return fmt.Errorf("failed to start deduct transaction: %w", err)
	}
	defer deductTx.Rollback()

	// Lock the profile row to ensure serialization
	var senderFullName string
	err = deductTx.QueryRowContext(ctx, "SELECT full_name FROM profiles WHERE id = $1 FOR UPDATE", userUUID).Scan(&senderFullName)
	if err != nil {
		return fmt.Errorf("failed to fetch profile: %w", err)
	}

	// Calculate user balance
	var currentBalance int64
	err = deductTx.QueryRowContext(ctx, "SELECT COALESCE(SUM(amount), 0) FROM ledger_entries WHERE profile_id = $1", userUUID).Scan(&currentBalance)
	if err != nil {
		return fmt.Errorf("failed to calculate current balance: %w", err)
	}

	if currentBalance < data.Amount {
		// Insufficient balance! Fail the transaction immediately
		_, err = deductTx.ExecContext(ctx, `
			UPDATE transactions
			SET status = 'FAILED', settlement_status = 'FAILED', description = description || ' - Insufficient Balance'
			WHERE id = $1
		`, txUUID)
		if err != nil {
			return fmt.Errorf("failed to update transaction status to FAILED: %w", err)
		}
		_ = deductTx.Commit()
		return fmt.Errorf("insufficient balance: %d satang available, need %d", currentBalance, data.Amount)
	}

	// Sufficient balance: insert ledger entry (debit) to reserve the funds
	newBalance := currentBalance - data.Amount
	_, err = deductTx.ExecContext(ctx, `
		INSERT INTO ledger_entries (id, transaction_id, profile_id, amount, balance_after, base_currency_amount, home_currency_amount)
		VALUES ($1, $2, $3, $4, $5, $4, $4)
	`, uuid.New(), txUUID, userUUID, -data.Amount, newBalance)
	if err != nil {
		return fmt.Errorf("failed to create ledger entry: %w", err)
	}

	if err := deductTx.Commit(); err != nil {
		return fmt.Errorf("failed to commit deduct transaction: %w", err)
	}

	log.Printf("Reserved funds of %d satang for transaction %s (User: %s)", data.Amount, data.TransactionID, data.UserID)

	// 3. Call external payment provider (SQRIL) outside the balance lock transaction
	payoutResult, err := w.PaymentEngine.ExecutePayout(ctx, "", data.Amount, "THB", data.PromptPayID, data.RecipientName, idempotencyKey, data.SqrilTxID, data.CustomerID)
	if err != nil {
		log.Printf("⚠️ Payment provider call failed: %v. Rolling back/refunding reserved funds.", err)

		payoutErr := err

		// Refund the user balance asynchronously!
		refundTx, rErr := w.DB.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelSerializable})
		if rErr != nil {
			return fmt.Errorf("failed to start refund transaction: %w", rErr)
		}
		defer refundTx.Rollback()

		// Lock profile row
		_ = refundTx.QueryRowContext(ctx, "SELECT full_name FROM profiles WHERE id = $1 FOR UPDATE", userUUID).Scan(&senderFullName)

		// Calculate current balance
		var balanceBeforeRefund int64
		_ = refundTx.QueryRowContext(ctx, "SELECT COALESCE(SUM(amount), 0) FROM ledger_entries WHERE profile_id = $1", userUUID).Scan(&balanceBeforeRefund)

		// Insert refund ledger entry (credit)
		_, err = refundTx.ExecContext(ctx, `
			INSERT INTO ledger_entries (id, transaction_id, profile_id, amount, balance_after, base_currency_amount, home_currency_amount)
			VALUES ($1, $2, $3, $4, $5, $4, $4)
		`, uuid.New(), txUUID, userUUID, data.Amount, balanceBeforeRefund+data.Amount)
		if err != nil {
			return fmt.Errorf("failed to insert refund ledger entry: %w", err)
		}

		// Update transactions status to failed
		_, err = refundTx.ExecContext(ctx, `
			UPDATE transactions
			SET status = 'FAILED', settlement_status = 'FAILED', provider_metadata = jsonb_set(provider_metadata, '{error}', $1)
			WHERE id = $2
		`, fmt.Sprintf(`"%s"`, payoutErr.Error()), txUUID)
		if err != nil {
			return fmt.Errorf("failed to update transaction status to failed: %w", err)
		}

		_ = refundTx.Commit()
		return fmt.Errorf("payment engine payout execution failed: %w (refunded)", payoutErr)
	}

	// 4. Payout succeeded: finalize transaction status in DB
	finalizeTx, fErr := w.DB.BeginTx(ctx, nil)
	if fErr != nil {
		return fmt.Errorf("failed to start finalize transaction: %w", fErr)
	}
	defer finalizeTx.Rollback()

	// Update transactions status to settled/success
	settlementStatus := "PENDING"
	switch payoutResult.Status {
	case "SUCCESS":
		settlementStatus = "SETTLED"
	case "FAILED":
		settlementStatus = "FAILED"
	}

	_, fErr = finalizeTx.ExecContext(ctx, `
		UPDATE transactions
		SET provider_metadata = jsonb_set(provider_metadata, '{external_id}', $1),
		    settlement_status = $2::settlement_status_enum,
		    status = $3
		WHERE id = $4
	`, fmt.Sprintf(`"%s"`, payoutResult.ExternalID), settlementStatus, payoutResult.Status, txUUID)
	if fErr != nil {
		return fmt.Errorf("failed to update transactions: %w", fErr)
	}

	// If the provider returned a FAILED status, refund the balance!
	if payoutResult.Status == "FAILED" {
		log.Printf("⚠️ Provider status returned FAILED. Performing refund for transaction %s.", data.TransactionID)
		// Lock profile row
		_ = finalizeTx.QueryRowContext(ctx, "SELECT full_name FROM profiles WHERE id = $1 FOR UPDATE", userUUID).Scan(&senderFullName)

		// Calculate current balance
		var balanceBeforeRefund int64
		_ = finalizeTx.QueryRowContext(ctx, "SELECT COALESCE(SUM(amount), 0) FROM ledger_entries WHERE profile_id = $1", userUUID).Scan(&balanceBeforeRefund)

		// Insert refund ledger entry (credit)
		_, err = finalizeTx.ExecContext(ctx, `
			INSERT INTO ledger_entries (id, transaction_id, profile_id, amount, balance_after, base_currency_amount, home_currency_amount)
			VALUES ($1, $2, $3, $4, $5, $4, $4)
		`, uuid.New(), txUUID, userUUID, data.Amount, balanceBeforeRefund+data.Amount)
		if err != nil {
			return fmt.Errorf("failed to insert failed-payout refund ledger entry: %w", err)
		}
	}

	if err := finalizeTx.Commit(); err != nil {
		return fmt.Errorf("failed to commit finalize transaction: %w", err)
	}

	log.Printf("✅ Successfully processed payout for transaction %s via engine, status: %s", data.TransactionID, payoutResult.Status)
	return nil
}

func (w *OutboxWorker) handleFailureInTx(tx *sql.Tx, id string, currentRetries int, err error) {
	newStatus := "RETRY_PENDING"
	if currentRetries >= 5 {
		newStatus = "FAILED"
	}

	_, err = tx.ExecContext(context.Background(), `
		UPDATE transaction_outbox 
		SET status = $1, error_message = $2
		WHERE id = $3
	`, newStatus, err.Error(), id)
	if err != nil {
		log.Printf("⚠️ Failed to update outbox status: %v", err)
	}
}
