package usecase_test

import (
	"context"
	"testing"

	"paysif/internal/usecase"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
)

func TestWalletService_ProcessPayment_Idempotency(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to open sqlmock: %v", err)
	}
	defer db.Close()

	service := &usecase.WalletService{DB: db}
	userID := uuid.New()
	amount := 100.0
	merchant := "Test Merchant"
	referenceID := "ref_123"

	t.Run("New Transaction", func(t *testing.T) {
		mock.ExpectBegin()
		mock.ExpectExec("INSERT INTO transactions").
			WithArgs(sqlmock.AnyArg(), userID, referenceID, int64(amount*100), "Pay per use: "+merchant, sqlmock.AnyArg()).
			WillReturnResult(sqlmock.NewResult(1, 1))
		mock.ExpectExec("INSERT INTO ledger_entries").
			WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), userID, int64(amount*100)).
			WillReturnResult(sqlmock.NewResult(1, 1))
		mock.ExpectExec("INSERT INTO transaction_outbox").
			WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), sqlmock.AnyArg()).
			WillReturnResult(sqlmock.NewResult(1, 1))
		mock.ExpectCommit()

		err := service.ProcessPayment(context.Background(), userID, amount, merchant, referenceID)
		assert.NoError(t, err)
		assert.NoError(t, mock.ExpectationsWereMet())
	})

	t.Run("Duplicate Transaction (Idempotent)", func(t *testing.T) {
		mock.ExpectBegin()
		mock.ExpectExec("INSERT INTO transactions").
			WithArgs(sqlmock.AnyArg(), userID, referenceID, int64(amount*100), "Pay per use: "+merchant, sqlmock.AnyArg()).
			WillReturnResult(sqlmock.NewResult(0, 0))
		// Note: No rollback or commit expected because it returns nil early?
		// Actually ProcessPayment has 'defer tx.Rollback()' and returns nil early.
		// sqlmock ExpectRollback is needed if Rollback is called.

		mock.ExpectRollback()

		err := service.ProcessPayment(context.Background(), userID, amount, merchant, referenceID)
		assert.NoError(t, err)
		assert.NoError(t, mock.ExpectationsWereMet())
	})
}
