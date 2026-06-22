package usecase

import (
	"context"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
)

func TestProcessPayment_Idempotency(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("an error '%s' was not expected when opening a stub database connection", err)
	}
	defer db.Close()

	s := &WalletService{DB: db}
	userID := uuid.New()
	amount := 100.0
	merchant := "TestMerchant"
	referenceID := "ref_123"

	t.Run("New Transaction", func(t *testing.T) {
		mock.ExpectBegin()
		// There are 6 placeholders in the query: $1, $2, $3, $4, $5, $6.
		// Query: (id, profile_id, reference_id, amount, description, settlement_status, gateway_fee, provider_metadata, created_at)
		// Values: ($1, $2, $3, $4, $5, 'SETTLED', 0, $6, NOW())
		mock.ExpectExec("INSERT INTO transactions").
			WithArgs(sqlmock.AnyArg(), userID, referenceID, int64(amount*100), "Pay per use: "+merchant, sqlmock.AnyArg()).
			WillReturnResult(sqlmock.NewResult(1, 1))

		mock.ExpectExec("INSERT INTO ledger_entries").WillReturnResult(sqlmock.NewResult(1, 1))
		mock.ExpectExec("INSERT INTO transaction_outbox").WillReturnResult(sqlmock.NewResult(1, 1))
		mock.ExpectCommit()

		err := s.ProcessPayment(context.Background(), userID, amount, merchant, referenceID)
		assert.NoError(t, err)
		assert.NoError(t, mock.ExpectationsWereMet())
	})

	t.Run("Duplicate Transaction", func(t *testing.T) {
		mock.ExpectBegin()
		mock.ExpectExec("INSERT INTO transactions").
			WithArgs(sqlmock.AnyArg(), userID, referenceID, int64(amount*100), "Pay per use: "+merchant, sqlmock.AnyArg()).
			WillReturnResult(sqlmock.NewResult(0, 0)) // 0 rows affected

		// If rows == 0, it returns nil immediately.
		// The defer tx.Rollback() will be called.
		mock.ExpectRollback()

		err := s.ProcessPayment(context.Background(), userID, amount, merchant, referenceID)
		assert.NoError(t, err)
		assert.NoError(t, mock.ExpectationsWereMet())
	})
}
