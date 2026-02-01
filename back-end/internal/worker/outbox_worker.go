package worker

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

// OutboxWorker processes pending events from the transaction_outbox.
type OutboxWorker struct {
	DB *sql.DB
}

// NewOutboxWorker creates a new worker instance.
func NewOutboxWorker(db *sql.DB) *OutboxWorker {
	return &OutboxWorker{DB: db}
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

func (w *OutboxWorker) processBatch(ctx context.Context) error {
	rows, err := w.DB.QueryContext(ctx, `
		SELECT id, event_type, payload, retry_count, COALESCE(last_attempt_at, '1970-01-01') 
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

	for rows.Next() {
		var id string
		var eventType string
		var payload []byte
		var retryCount int
		var lastAttempt time.Time
		if err := rows.Scan(&id, &eventType, &payload, &retryCount, &lastAttempt); err != nil {
			log.Printf("Failed to scan row: %v", err)
			continue
		}

		log.Printf("Processing event %s | Type: %s | Attempt: %d", id, eventType, retryCount+1)

		// Execute with Idempotency
		err := w.handleEvent(ctx, id, eventType, payload)

		if err == nil {
			// Success
			_, _ = w.DB.ExecContext(ctx, `
				UPDATE transaction_outbox 
				SET status = 'PROCESSED', processed_at = NOW(), last_attempt_at = NOW(), retry_count = retry_count + 1
				WHERE id = $1
			`, id)
		} else {
			// Failure handling
			log.Printf("Event %s failed: %v", id, err)
			w.handleFailure(ctx, id, retryCount, err)
		}
	}

	return rows.Err()
}

func (w *OutboxWorker) handleEvent(ctx context.Context, outboxID string, eventType string, payload []byte) error {
	switch eventType {
	case "PROMPTPAY_PAYOUT":
		return w.processPromptPayPayout(ctx, outboxID, payload)
	case "TRANSFER_COMPLETED":
		// Logic for notification or other side effects
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
	}

	if err := json.Unmarshal(payload, &data); err != nil {
		return fmt.Errorf("failed to unmarshal payout payload: %w", err)
	}

	omiseSecret := os.Getenv("OMISE_SECRET_KEY")
	if omiseSecret == "" {
		log.Println("⚠️ OMISE_SECRET_KEY not set, skipping real payout call (simulating success)")
		return nil
	}

	client := &http.Client{Timeout: 30 * time.Second}

	// 1. Create Recipient
	recURL := "https://api.omise.co/recipients"
	recForm := url.Values{}
	recForm.Set("name", data.RecipientName)
	recForm.Set("type", "individual")
	recForm.Set("bank_account[brand]", "scb")
	recForm.Set("bank_account[number]", data.PromptPayID)
	recForm.Set("bank_account[name]", data.RecipientName)

	req, err := http.NewRequestWithContext(ctx, "POST", recURL, strings.NewReader(recForm.Encode()))
	if err != nil {
		return err
	}
	req.SetBasicAuth(omiseSecret, "")
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("omise recipient API error: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 500 {
		return fmt.Errorf("omise recipient API server error: %d", resp.StatusCode)
	}

	var recData struct {
		ID    string `json:"id"`
		Error *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	json.NewDecoder(resp.Body).Decode(&recData)

	if recData.ID == "" {
		msg := "unknown error"
		if recData.Error != nil {
			msg = recData.Error.Message
		}
		return fmt.Errorf("failed to create Omise recipient: %s", msg)
	}

	// 2. Create Transfer
	trsfURL := "https://api.omise.co/transfers"
	trsfForm := url.Values{}
	trsfForm.Set("amount", fmt.Sprintf("%d", data.Amount))
	trsfForm.Set("recipient", recData.ID)

	req, err = http.NewRequestWithContext(ctx, "POST", trsfURL, strings.NewReader(trsfForm.Encode()))
	if err != nil {
		return err
	}
	req.SetBasicAuth(omiseSecret, "")
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	// Use outbox ID as idempotency key for Omise
	req.Header.Set("Omise-Idempotency-Key", idempotencyKey)

	resp, err = client.Do(req)
	if err != nil {
		return fmt.Errorf("omise transfer API error: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 500 {
		return fmt.Errorf("omise transfer API server error: %d", resp.StatusCode)
	}

	if resp.StatusCode >= 400 {
		var errData struct {
			Message string `json:"message"`
		}
		json.NewDecoder(resp.Body).Decode(&errData)
		return fmt.Errorf("omise transfer API failed: %s", errData.Message)
	}

	log.Printf("✅ Successfully processed Omise payout for transaction %s", data.TransactionID)
	return nil
}

func (w *OutboxWorker) handleFailure(ctx context.Context, id string, currentRetries int, err error) {
	newStatus := "RETRY_PENDING"
	if currentRetries >= 5 {
		newStatus = "FAILED"
	}

	_, _ = w.DB.ExecContext(ctx, `
		UPDATE transaction_outbox 
		SET status = $1, last_attempt_at = NOW(), retry_count = retry_count + 1, error_message = $2
		WHERE id = $3
	`, newStatus, err.Error(), id)
}
