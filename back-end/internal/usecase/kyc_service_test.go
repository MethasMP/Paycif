package usecase_test

import (
	"context"
	"os"
	"strings"
	"testing"

	"paysif/internal/usecase"

	"github.com/google/uuid"
	"github.com/joho/godotenv"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"paysif/internal/infrastructure/logger"

	"database/sql"

	_ "github.com/jackc/pgx/v5/stdlib"
)

// To run this test:
// 1. Ensure .env is present in back-end directory
func TestKYC_EndToEndFlow(t *testing.T) {
	// 1. Initial Load
	_ = godotenv.Load(".env")
	_ = godotenv.Load("../../.env") // Support different running contexts
	logger.Init()

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		t.Skip("Skipping E2E test: DATABASE_URL not set")
	}

	// Supabase Pooler (Transaction Mode) doesn't support prepared statements properly.
	if !strings.Contains(dbURL, "simple_protocol") {
		if strings.Contains(dbURL, "?") {
			dbURL += "&default_query_exec_mode=simple_protocol"
		} else {
			dbURL += "?default_query_exec_mode=simple_protocol"
		}
	}

	db, err := sql.Open("pgx", dbURL)
	require.NoError(t, err)
	defer db.Close()

	audit := usecase.NewAuditService(db)
	svc := usecase.NewKYCService(db, audit)

	userID := uuid.New()
	ctx := context.Background()

	// 0. Create dummy Profile (Required by Foreign Key)
	_, err = db.Exec("INSERT INTO profiles (id, username, full_name, email) VALUES ($1, $2, $3, $4)", userID, "testuser_"+userID.String()[:8], "Test User", "test@example.com")
	require.NoError(t, err)
	defer db.Exec("DELETE FROM profiles WHERE id = $1", userID)

	// --- PHASE 1: Register OnRamp Customer ---
	t.Run("Phase 1: Register OnRamp Customer", func(t *testing.T) {
		dto := usecase.OnRampCustomerDTO{
			UserID:         userID,
			FullName:       "John Doe",
			PassportNumber: "AB123456",
			Nationality:    "TH",
		}

		onRampID, err := svc.RegisterOnRampCustomer(ctx, dto)
		assert.NoError(t, err)
		assert.Contains(t, onRampID, "onramp_cust_")

		// Verify state is PENDING_ONRAMP_VERIFICATION
		status, err := svc.GetOnRampKycStatus(ctx, userID)
		assert.NoError(t, err)
		assert.Equal(t, "PENDING_ONRAMP_VERIFICATION", status.KycStatus)

		// Verify id_last_4 is correctly stored as "3456" (from "AB123456")
		var idLast4 sql.NullString
		err = db.QueryRow("SELECT id_last_4 FROM profiles WHERE id = $1", userID).Scan(&idLast4)
		assert.NoError(t, err)
		assert.True(t, idLast4.Valid)
		assert.Equal(t, "3456", idLast4.String)
	})

	// --- PHASE 2: Sync OnRamp Status ---
	t.Run("Phase 2: Sync OnRamp Status", func(t *testing.T) {
		err := svc.SyncOnRampKycStatus(ctx, userID, "VERIFIED", "tier1")
		assert.NoError(t, err)

		// Verify state is VERIFIED
		status, err := svc.GetOnRampKycStatus(ctx, userID)
		assert.NoError(t, err)
		assert.Equal(t, "VERIFIED", status.KycStatus)
		assert.Equal(t, "tier1", status.KycTier)
		assert.NotNil(t, status.ConfirmedAt)
	})
}
