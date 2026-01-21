package main

import (
	"fmt"
	"zappay/database"
	"zappay/models"
)

func main() {
	// Verify models are accessible
	_ = models.Profile{}
	_ = models.Wallet{}
	_ = models.Transaction{}
	_ = models.LedgerEntry{}

	// Verify database connection function exists
	// We won't actually call it to avoid runtime error without env var
	fmt.Printf("Database connect function type: %T\n", database.Connect)
}
