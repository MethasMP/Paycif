package models

import (
	"time"

	"github.com/google/uuid"
)

// TransactionHistoryDTO represents a flattened transaction view for the API
type TransactionHistoryDTO struct {
	ID       uuid.UUID `json:"id"`
	WalletID uuid.UUID `json:"wallet_id"`
	Type     string    `json:"type"`   // 'CREDIT' or 'DEBIT'
	Amount   int64     `json:"amount"` // Absolute value for display, or native? User requested Type and Amount. Usually helpful to keep native sign or separate.
	// User said: "If type is 'DEBIT', show a minus sign... if 'CREDIT'..."
	// It's easiest if I just set Type based on sign, and send absolute amount?
	// OR send signed amount and let UI decide.
	// Plan said: "derived from amount sign".
	Description string    `json:"description"`
	CreatedAt   time.Time `json:"created_at"`
}
