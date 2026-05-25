package service

import (
	"context"
	"database/sql"
	"encoding/json"
	"log/slog"
	"paysif/internal/infrastructure/logger"

	"github.com/google/uuid"
)

type AuditService struct {
	DB *sql.DB
}

func NewAuditService(db *sql.DB) *AuditService {
	return &AuditService{DB: db}
}

func (s *AuditService) Log(ctx context.Context, userID uuid.UUID, action, resourceType, resourceID string, metadata map[string]interface{}) {
	metaJSON, _ := json.Marshal(metadata)
	
	// Get request ID from context for linking logs
	requestID, _ := ctx.Value(logger.RequestIDKey).(string)

	// 1. Database (Persistent Audit Trail)
	_, err := s.DB.ExecContext(ctx, `
		INSERT INTO audit_logs (user_id, action, resource_type, resource_id, metadata, request_id)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, userID, action, resourceType, resourceID, metaJSON, requestID)

	if err != nil {
		// Log the failure to write to audit log
		logger.WithContext(ctx).Error("Failed to write audit log", 
			slog.Any("error", err),
			slog.String("action", action),
		)
		return
	}

	// 2. Structured Log (Real-time alerting/tracking)
	logger.WithContext(ctx).Info("Audit Log Created",
		slog.String("user_id", userID.String()),
		slog.String("action", action),
		slog.String("resource", resourceType),
		slog.Any("meta", metadata),
	)
}
