package main

import (
	"fmt"
	"paysif/internal/adapter/repository"
	models "paysif/internal/domain/entities"
)

func main() {
	// Verify models are accessible
	_ = models.Profile{}
	_ = models.Wallet{}
	_ = models.Transaction{}
	_ = models.LedgerEntry{}

	// Verify database connection function exists
	// We won't actually call it to avoid runtime error without env var
	fmt.Printf("Database connect function type: %T\n", repository.Connect)
}
