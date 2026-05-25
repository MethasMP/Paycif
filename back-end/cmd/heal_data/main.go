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

	fmt.Println("🛠️ Starting Data Healing Process...")

	// SQL to sync transactions with ledger_entries
	query := `
		UPDATE transactions t
		SET 
			amount = ABS(le.amount),
			wallet_id = le.wallet_id,
			type = 'PAYOUT',
			status = 'SUCCESS'
		FROM ledger_entries le
		WHERE t.id = le.transaction_id
		  AND (t.amount = 0 OR t.amount IS NULL)
		  AND t.wallet_id IS NULL
		  AND t.description LIKE 'PromptPay%'
	`

	result, err := database.DB.Exec(query)
	if err != nil {
		log.Fatalf("❌ Failed to heal data: %v", err)
	}

	rowsAffected, _ := result.RowsAffected()
	fmt.Printf("✅ Success! Fixed %d broken transactions.\n", rowsAffected)
	
	if rowsAffected == 0 {
		fmt.Println("ℹ️ No broken transactions found or they were already fixed.")
	}
}
