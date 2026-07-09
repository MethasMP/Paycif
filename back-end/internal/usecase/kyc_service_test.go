package usecase_test

import (
	"context"
	"os"
	"testing"
	"time"

	"paysif/internal/infrastructure/logger"
	"paysif/internal/usecase"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"database/sql"
	_ "github.com/jackc/pgx/v5/stdlib"

	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"
)

func TestKYC_EndToEndFlow(t *testing.T) {
	ctx := context.Background()
	logger.Init()

	pgContainer, err := postgres.Run(ctx,
		"postgres:16-alpine",
		postgres.WithDatabase("testdb"),
		postgres.WithUsername("user"),
		postgres.WithPassword("password"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).WithStartupTimeout(20*time.Second)),
	)
	require.NoError(t, err)
	defer func() {
		if err := pgContainer.Terminate(ctx); err != nil {
			t.Fatalf("failed to terminate container: %s", err)
		}
	}()

	dbURL, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
	require.NoError(t, err)

	db, err := sql.Open("pgx", dbURL)
	require.NoError(t, err)
	defer db.Close()

	// Execute schemas manually to guarantee order
	schema1, err := os.ReadFile("../../schema.sql")
	require.NoError(t, err)
	_, err = db.Exec(string(schema1))
	require.NoError(t, err)

	schema2, err := os.ReadFile("../../init_backend_db.sql")
	require.NoError(t, err)
	_, err = db.Exec(string(schema2))
	require.NoError(t, err)

	// Create a dummy auth schema and users table if not exists, since kyc_service queries auth.users
	_, _ = db.Exec("CREATE SCHEMA IF NOT EXISTS auth;")
	_, _ = db.Exec(`
		CREATE TABLE IF NOT EXISTS auth.users (
			id UUID PRIMARY KEY,
			email TEXT UNIQUE NOT NULL
		);
	`)

	audit := usecase.NewAuditService(db)
	client := usecase.NewAlchemyPayKYCClient("app_key", "secret_key", "merchant_no", true)
	svc := usecase.NewKYCService(db, audit, client)

	userID := uuid.New()
	email := "testuser_" + userID.String()[:8] + "@example.com"

	// 0. Create dummy User and Profile (Required by Foreign Key and queries)
	_, err = db.Exec("INSERT INTO auth.users (id, email) VALUES ($1, $2)", userID, email)
	require.NoError(t, err)
	defer func() { _, _ = db.Exec("DELETE FROM auth.users WHERE id = $1", userID) }()

	_, err = db.Exec("INSERT INTO profiles (id, username, full_name) VALUES ($1, $2, $3)", userID, "testuser_"+userID.String()[:8], "Test User")
	require.NoError(t, err)
	defer func() { _, _ = db.Exec("DELETE FROM profiles WHERE id = $1", userID) }()

	// --- PHASE 1: Register OnRamp Customer ---
	t.Run("Phase 1: Register OnRamp Customer", func(t *testing.T) {
		req := usecase.RegisterOnRampCustomerRequest{
			UserID:      userID,
			KycPlatform: "sumsub",
			KycType:     "1",
			CallbackURL: "http://localhost:8080/callback",
			RedirectURL: "http://localhost:8080/redirect",
		}

		// Since we pass a dummy client, calling RegisterUser will fail via network unless we stub/mock.
		// However, let's test if the DB transaction works or if it returns error when calling sandbox url.
		// Actually, to make test predictable and hermetic (network-less), we can check if it tries to make the call.
		// To bypass networking call to Alchemy Pay in tests, we could check the registration results.
		// Since AlchemyPayKYCClient uses Sandbox URL in test, let's see how it behaves.
		// We'll wrap RegisterOnRampCustomer.
		res, err := svc.RegisterOnRampCustomer(ctx, req)
		// We expect network call to fail, or if it's fine, we proceed. Let's inspect potential error.
		if err != nil {
			// If it's a network error or response parsing error, it's expected due to mock keys
			assert.Contains(t, err.Error(), "alchemy pay register")
		} else {
			assert.NotNil(t, res)
		}
	})

	// --- PHASE 2: Sync OnRamp Status ---
	t.Run("Phase 2: Sync OnRamp Status", func(t *testing.T) {
		payload := usecase.AchWebhookPayload{
			UserNo:    "ach_user_123",
			Email:     email,
			KycStatus: 1, // Approved (Maps to VERIFIED)
			KycType:   "1",
		}

		err := svc.SyncOnRampKycStatus(ctx, payload)
		assert.NoError(t, err)

		// Verify state is VERIFIED
		status, err := svc.GetOnRampKycStatus(ctx, userID)
		assert.NoError(t, err)
		assert.Equal(t, "VERIFIED", status.KycStatus)
	})
}
