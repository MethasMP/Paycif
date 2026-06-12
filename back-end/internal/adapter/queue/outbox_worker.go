package queue

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"paysif/internal/usecase"

	"github.com/google/uuid"
)

// OutboxWorker processes pending events from the transaction_outbox.
type OutboxWorker struct {
	DB            *sql.DB
	PaymentEngine *usecase.PaymentEngine
}

// NewOutboxWorker creates a new worker instance.
func NewOutboxWorker(db *sql.DB, pe *usecase.PaymentEngine) *OutboxWorker {
	return &OutboxWorker{
		DB:            db,
		PaymentEngine: pe,
	}
}

// Run starts the worker loop.
func (w *OutboxWorker) Run(ctx context.Context) {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	log.Println("Resilient Outbox worker started...")

	for {
		select {
		case <-ctx.Done():
			log.Println("Outbox worker stopping...")
			return
		case <-ticker.C:
			if err := w.processBatch(ctx); err != nil {
				log.Printf("Error processing batch: %v", err)
			}
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
	}

	if err := json.Unmarshal(payload, &data); err != nil {
		return fmt.Errorf("failed to unmarshal payout payload: %w", err)
	}

	txUUID, err := uuid.Parse(data.TransactionID)
	if err != nil {
		return fmt.Errorf("invalid transaction uuid: %w", err)
	}

	// 1. Local State Check (Fix 7) - Check if already completed via webhook
	var dbStatus string
	err = w.DB.QueryRowContext(ctx, "SELECT COALESCE(status, 'PENDING') FROM transactions WHERE id = $1", txUUID).Scan(&dbStatus)
	if err == nil && (dbStatus == "SUCCESS" || dbStatus == "SETTLED" || dbStatus == "COMPLETED") {
		log.Printf("ℹ️ Transaction %s already completed in DB. Skipping API execution.", data.TransactionID)
		return nil
	}

	// 2. Call PaymentEngine to execute payout (Fix 2)
	payoutResult, err := w.PaymentEngine.ExecutePayout(ctx, "", data.Amount, "THB", data.PromptPayID, data.RecipientName, idempotencyKey, data.SqrilTxID, data.CustomerID)
	if err != nil {
		return fmt.Errorf("payment engine payout execution failed: %w", err)
	}

	// 3. Update transaction status in DB
	_, err = w.DB.ExecContext(ctx, `
		UPDATE transactions 
		SET provider_metadata = jsonb_set(provider_metadata, '{external_id}', $1),
		    settlement_status = $2,
		    status = $2
		WHERE id = $3
	`, fmt.Sprintf(`"%s"`, payoutResult.ExternalID), payoutResult.Status, txUUID)
	if err != nil {
		log.Printf("⚠️ Failed to update transaction %s status to %s: %v", data.TransactionID, payoutResult.Status, err)
	}

	log.Printf("✅ Successfully processed payout for transaction %s via engine, status: %s", data.TransactionID, payoutResult.Status)
	return nil
}

func (w *OutboxWorker) handleFailureInTx(tx *sql.Tx, id string, currentRetries int, err error) {
	newStatus := "RETRY_PENDING"
	if currentRetries >= 5 {
		newStatus = "FAILED"
	}

	_, _ = tx.ExecContext(context.Background(), `
		UPDATE transaction_outbox 
		SET status = $1, error_message = $2
		WHERE id = $3
	`, newStatus, err.Error(), id)
}
