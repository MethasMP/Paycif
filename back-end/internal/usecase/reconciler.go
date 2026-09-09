package usecase

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"strings"
	"time"
)

// StartReconciliationWorker starts a background ticker that reconciles stuck payment intents.
func StartReconciliationWorker(ctx context.Context, db *sql.DB, service *PaymentOrchestrationService) {
	ticker := time.NewTicker(30 * time.Second) // Check every 30 seconds for quick local feedback
	go func() {
		defer ticker.Stop()
		log.Println("🔄 [RECONCILER] Background transaction recovery worker started.")
		for {
			select {
			case <-ctx.Done():
				log.Println("🔄 [RECONCILER] Background transaction recovery worker stopping.")
				return
			case <-ticker.C:
				runReconciliationCycle(ctx, db, service)
			}
		}
	}()
}

func runReconciliationCycle(ctx context.Context, db *sql.DB, service *PaymentOrchestrationService) {
	// Create a per-cycle context with deadline to prevent hangs
	cycleCtx, cancel := context.WithTimeout(ctx, 25*time.Second)
	defer cancel()

	// 1. Claim batch of stuck intents inside a short transaction to prevent multi-pod double-processing
	tx, err := db.BeginTx(cycleCtx, nil)
	if err != nil {
		log.Printf("❌ [RECONCILER] Error starting batch transaction: %v", err)
		return
	}
	defer tx.Rollback()

	rows, err := tx.QueryContext(cycleCtx, `
		SELECT id, user_id, amount, promptpay_id, recipient_name, sqril_tx_id, status 
		FROM payout_intents 
		WHERE status IN ('PENDING', 'PAYMENT_SUCCESS_PAYOUT_PENDING') 
		AND created_at < NOW() - INTERVAL '1 minute'
		LIMIT 50 
		FOR UPDATE SKIP LOCKED
	`)
	if err != nil {
		log.Printf("❌ [RECONCILER] Error querying pending intents: %v", err)
		return
	}
	defer rows.Close()

	var intents []PayoutIntent
	for rows.Next() {
		var intent PayoutIntent
		if err := rows.Scan(&intent.ID, &intent.UserID, &intent.Amount, &intent.PromptPayID, &intent.RecipientName, &intent.SqrilTxID, &intent.Status); err == nil {
			intents = append(intents, intent)
		}
	}
	if err := rows.Err(); err != nil {
		log.Printf("❌ [RECONCILER] Error scanning pending intents rows: %v", err)
		return
	}
	rows.Close()

	if len(intents) == 0 {
		return
	}

	// Update status of claimed intents to RECONCILING to block other worker instances
	for _, intent := range intents {
		_, err = tx.ExecContext(cycleCtx, "UPDATE payout_intents SET status = 'RECONCILING' WHERE id = $1", intent.ID)
		if err != nil {
			log.Printf("❌ [RECONCILER] Failed to mark intent %s as RECONCILING: %v", intent.ID, err)
			return
		}
	}

	if err := tx.Commit(); err != nil {
		log.Printf("❌ [RECONCILER] Failed to commit batch claim: %v", err)
		return
	}

	log.Printf("🔄 [RECONCILER] Found %d pending intents older than 1 minute. Reconciling...", len(intents))

	for _, intent := range intents {
		log.Printf("🔄 [RECONCILER] Reconciling stuck intent %s (Original Status: %s, Amount: %d satang)...", intent.ID, intent.Status, intent.Amount)

		// 2. Check the real partner API (SQRIL) status
		isFinished := false
		if service.PaymentEngine != nil {
			if prov, ok := service.PaymentEngine.GetProvider("sqril"); ok {
				if sqrilProv, ok := prov.(*SqrilProvider); ok {
					// Verify status on partner API
					txDetails, err := sqrilProv.GetTransaction(cycleCtx, intent.SqrilTxID)
					if err != nil {
						log.Printf("❌ [RECONCILER] Sqril status lookup failed for intent %s: %v", intent.ID, err)
						// Reset status back so it can be retried later
						_ = service.UpdatePayoutIntentStatus(cycleCtx, intent.ID, intent.Status)
						continue
					}
					
					// Sqril statuses: Mock provider defaults to empty transaction structure.
					// Handle sandbox mock transaction status or real "SUCCESS"/"FINISHED" statuses.
					statusStr := strings.ToUpper(txDetails.Transaction.Status)
					if sqrilProv.ClientID == "mock-client-id" || statusStr == "SUCCESS" || statusStr == "FINISHED" || statusStr == "COMPLETED" || statusStr == "ACCEPTED" {
						isFinished = true
					} else {
						log.Printf("⚠️ [RECONCILER] Sqril transaction status for intent %s is %s. Resetting intent to original state.", intent.ID, txDetails.Transaction.Status)
						_ = service.UpdatePayoutIntentStatus(cycleCtx, intent.ID, intent.Status)
						continue
					}
				}
			}
		}

		if !isFinished {
			log.Printf("❌ [RECONCILER] Could not verify finished status from payment engine for intent %s. Skipping.", intent.ID)
			_ = service.UpdatePayoutIntentStatus(cycleCtx, intent.ID, intent.Status)
			continue
		}

		// 3. Process payment ledger credit (only if not already credited in a previous run)
		if intent.Status == "PENDING" {
			desc := fmt.Sprintf("Reconciled Deposit: %d satang", intent.Amount)
			mockOrderNo := "rec_" + intent.ID.String()
			if err := service.ProcessPayment(cycleCtx, intent.UserID, float64(intent.Amount)/100.0, desc, mockOrderNo); err != nil {
				log.Printf("❌ [RECONCILER] Ledger credit failed for intent %s: %v", intent.ID, err)
				_ = service.UpdatePayoutIntentStatus(cycleCtx, intent.ID, "PENDING")
				continue
			}
		}

		// 4. Trigger Instant payout to PromptPay
		payoutResp, err := service.PayoutToPromptPay(cycleCtx, PayoutRequest{
			UserID:         intent.UserID,
			Amount:         intent.Amount,
			PromptPayID:    intent.PromptPayID,
			RecipientName:  intent.RecipientName,
			IdempotencyKey: intent.ID.String(),
			SqrilTxID:      intent.SqrilTxID,
		})
		if err != nil {
			log.Printf("⚠ [RECONCILER] Payout failed for intent %s (outbox will retry): %v", intent.ID, err)
			_ = service.UpdatePayoutIntentStatus(cycleCtx, intent.ID, "PAYMENT_SUCCESS_PAYOUT_PENDING")
			continue
		}

		_ = service.UpdatePayoutIntentStatus(cycleCtx, intent.ID, "COMPLETED")
		log.Printf("🎉 [RECONCILER] Successfully recovered stuck intent %s. Status set to COMPLETED (status=%s)", intent.ID, payoutResp.Status)
	}
}
