package main

import (
	"fmt"
	"log"
	"paysif/database"

	_ "github.com/joho/godotenv/autoload"
)

func main() {
	if err := database.Connect(); err != nil {
		log.Fatal(err)
	}
	defer database.Close()

	// 1. Check Transactions
	fmt.Println("\n--- Last 5 Transactions ---")
	rows, err := database.DB.Query(`
		SELECT id, description, created_at, settlement_status 
		FROM transactions 
		ORDER BY created_at DESC 
		LIMIT 5
	`)
	if err != nil {
		log.Fatal(err)
	}
	defer rows.Close()

	for rows.Next() {
		var id, desc, status string
		var createdAt string
		rows.Scan(&id, &desc, &createdAt, &status)
		fmt.Printf("[%s] %s (%s) - %s\n", createdAt, desc, status, id)
	}

	// 2. Check Ledger Entries
	fmt.Println("\n--- Last 5 Ledger Entries ---")
	lRows, err := database.DB.Query(`
		SELECT id, amount, created_at 
		FROM ledger_entries 
		ORDER BY created_at DESC 
		LIMIT 5
	`)
	if err != nil {
		log.Fatal(err)
	}
	defer lRows.Close()

	for lRows.Next() {
		var id string
		var amount int
		var createdAt string
		lRows.Scan(&id, &amount, &createdAt)
		fmt.Printf("[%s] Amount: %d satang - %s\n", createdAt, amount, id)
	}
}
