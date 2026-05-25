package service_test

import (
	"context"
	"encoding/base64"
	"os"
	"strings"
	"testing"

	"paysif/internal/service"

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

	encryptionKey := os.Getenv("ENCRYPTION_KEY")
	if encryptionKey == "" {
		os.Setenv("ENCRYPTION_KEY", "p4ssw0rd_v3ry_s3cr3t_paysif_2026") // Fallback for local runners
	}

	db, err := sql.Open("pgx", dbURL)
	require.NoError(t, err)
	defer db.Close()

	crypto := service.NewCryptoService()
	audit := service.NewAuditService(db)
	svc := service.NewKYCService(db, crypto, audit)

	userID := uuid.New()
	ctx := context.Background()

	// 0. Create dummy Profile (Required by Foreign Key)
	_, err = db.Exec("INSERT INTO profiles (id, full_name, email) VALUES ($1, $2, $3)", userID, "Test User", "test@example.com")
	require.NoError(t, err)
	defer db.Exec("DELETE FROM profiles WHERE id = $1", userID)

	// --- PHASE 1: NFC Submission (Passive Auth) ---
	t.Run("Phase 1: NFC Submission", func(t *testing.T) {
		// Mock data groups
		dg1 := []byte("DG1_DATA")
		dg2 := []byte("DG2_DATA_ICAO_COMPLIANT_IMAGE")
		sod := []byte("") // Skip signature check in mock test by using empty or valid sod

		dto := service.KYCSubmissionDTO{
			UserID:         userID,
			FullName:       "John Doe",
			PassportNumber: "AB123456",
			Nationality:    "TH",
			DG1:            dg1,
			DG2:            dg2,
			SOD:            sod,
		}

		err := svc.SubmitKYC(ctx, dto)
		assert.NoError(t, err)

		// Verify state is PENDING_BIOMETRIC
		var status string
		err = db.QueryRow("SELECT kyc_status FROM identity_verification WHERE user_id = $1", userID).Scan(&status)
		assert.NoError(t, err)
		assert.Equal(t, "PENDING_BIOMETRIC", status)
	})

	// --- PHASE 2: Biometric Matching (Liveness + Face) ---
	t.Run("Phase 2: Biometric Matching", func(t *testing.T) {
		// Simulate a valid session ID from the previous step
		sessionID := uuid.New().String()

		// Mocked selfie (Base64)
		// Needs to be > 1KB to pass mock logic
		mockSelfie := make([]byte, 2048)
		for i:=0; i<len(mockSelfie); i++ { mockSelfie[i] = 0xAA }
		selfieB64 := base64.StdEncoding.EncodeToString(mockSelfie)

		err := svc.VerifySelfie(ctx, userID, selfieB64, sessionID)
		assert.NoError(t, err)

		// Verify state is VERIFIED
		var status string
		err = db.QueryRow("SELECT kyc_status FROM identity_verification WHERE user_id = $1", userID).Scan(&status)
		assert.NoError(t, err)
		assert.Equal(t, "VERIFIED", status)
	})

	// Cleanup
	db.Exec("DELETE FROM identity_verification WHERE user_id = $1", userID)
}
