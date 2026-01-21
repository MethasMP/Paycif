package service

import (
	"log"
	"time"
)

// AlertLevel defines the severity of the alert
type AlertLevel string

const (
	AlertLevelInfo     AlertLevel = "INFO"
	AlertLevelWarning  AlertLevel = "WARNING"
	AlertLevelCritical AlertLevel = "CRITICAL"
)

// AlertService handles system notifications.
// In a real system, this would push to Slack, PagerDuty, or Sentry.
type AlertService struct{}

func NewAlertService() *AlertService {
	return &AlertService{}
}

// Notify sends an alert with the given level and message.
func (s *AlertService) Notify(level AlertLevel, title, message string) {
	// For MVP, we log to stdout with specific prefixes for log monitoring tools.
	// E.g. [ALERT:CRITICAL] Integrity Breach Detected!
	timestamp := time.Now().Format(time.RFC3339)
	log.Printf("[%s] [ALERT:%s] %s - %s\n", timestamp, level, title, message)
}
