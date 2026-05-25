package service

import (
	"context"
	"log"

	"github.com/jackc/pgx/v4/pgxpool"
)

// NotificationService defines the contract for sending user notifications
type NotificationService interface {
	SendTransactionAlert(ctx context.Context, userID string, amount float64, currency string, txnType string) error
	UpdateFCMToken(ctx context.Context, userID string, token string) error
}

type notificationServiceImpl struct {
	db  *pgxpool.Pool
	// In the future, we will inject a firebase client here
	// fcmClient *messaging.Client 
}

func NewNotificationService(db *pgxpool.Pool) NotificationService {
	return &notificationServiceImpl{
		db: db,
	}
}

// SendTransactionAlert checks user preference and sends a silent push notification
func (s *notificationServiceImpl) SendTransactionAlert(ctx context.Context, userID string, amount float64, currency string, txnType string) error {
	// 1. Check User Preference (Gatekeeper)
	var allowTxAlerts bool
	var fcmToken *string

	err := s.db.QueryRow(ctx, `
		SELECT notification_transaction, fcm_token 
		FROM profiles 
		WHERE id = $1
	`, userID).Scan(&allowTxAlerts, &fcmToken)

	if err != nil {
		log.Printf("⚠️ [Notification] Failed to check preference for user %s: %v", userID, err)
		return err // Or return nil to fail silently
	}

	// 2. Strict Policy Enforcement
	if !allowTxAlerts {
		log.Printf("🚫 [Notification] Suppressed for user %s based on preference.", userID)
		return nil // User opted out
	}

	if fcmToken == nil || *fcmToken == "" {
		log.Printf("ℹ️ [Notification] No FCM token for user %s. Skipping.", userID)
		return nil
	}

	// 3. Send Notification (Mock for now, ready for FCM integration)
	// In production, this would call FCM API
	log.Printf("🚀 [Notification] SENDING Push to %s: You have a new %s transaction of %s %.2f", userID, txnType, currency, amount)
	
	// Implementation Note:
	// Here we would construct a "Data Message" (Silent Push) containing just the txnID
	// The mobile app would wake up, verify the signature, and fetch details itself.

	return nil
}

func (s *notificationServiceImpl) UpdateFCMToken(ctx context.Context, userID string, token string) error {
	_, err := s.db.Exec(ctx, `
		UPDATE profiles 
		SET fcm_token = $1, updated_at = NOW() 
		WHERE id = $2
	`, token, userID)
	
	if err != nil {
		log.Printf("❌ Failed to update FCM token: %v", err)
		return err
	}
	
	log.Printf("✅ FCM Token updated for user %s", userID)
	return nil
}
