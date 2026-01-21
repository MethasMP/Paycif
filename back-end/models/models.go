package models

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// Profile represents a user in the system.
type Profile struct {
	ID        uuid.UUID `json:"id"`
	Username  string    `json:"username"`
	FullName  string    `json:"full_name"` // Nullable in DB, but string is fine if we handle empty
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Wallet represents a currency balance for a user.
type Wallet struct {
	ID        uuid.UUID `json:"id"`
	ProfileID uuid.UUID `json:"profile_id"`
	Currency  string    `json:"currency"`
	Balance   int64     `json:"balance"` // Stored in minor units (e.g., cents)
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Transaction represents a financial event grouping ledger entries.
type Transaction struct {
	ID          uuid.UUID       `json:"id"`
	ReferenceID *string         `json:"reference_id"` // Nullable
	Description string          `json:"description"`
	CreatedAt   time.Time       `json:"created_at"`
	Metadata    json.RawMessage `json:"metadata"` // JSONB
}

// LedgerEntry represents a single debit or credit to a wallet.
type LedgerEntry struct {
	ID            uuid.UUID `json:"id"`
	TransactionID uuid.UUID `json:"transaction_id"`
	WalletID      uuid.UUID `json:"wallet_id"`
	Amount        int64     `json:"amount"` // Positive = Credit, Negative = Debit
	CreatedAt     time.Time `json:"created_at"`
}

// JSONB implementation for sql.Scanner/Valuer if needed,
// strictly creating structs as requested.
