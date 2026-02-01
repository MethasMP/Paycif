package main

import (
	"fmt"
	"log"
	"net/http"
	url_pkg "net/url"
	"os"
	"strings"

	"paysif/database"

	_ "github.com/joho/godotenv/autoload"
)

func main() {
	if err := database.Connect(); err != nil {
		log.Fatal(err)
	}
	defer database.Close()

	fmt.Println("🛠️  [Healing] Fixing DB records + Syncing to Omise...")

	// 1. First, Heal database records using ledger truth
	healQuery := `
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
	`
	res, err := database.DB.Exec(healQuery)
	if err != nil {
		log.Fatal(err)
	}
	fixed, _ := res.RowsAffected()
	fmt.Printf("✅ DB Healed: %d rows updated.\n", fixed)

	// 2. Now find transactions that exist in DB but NOT in Omise (Pending/Unsettled)
	// For simplicity, we sync ones marked as PromptPay in description which were just fixed.
	rows, err := database.DB.Query(`
		SELECT id, reference_id, amount 
		FROM transactions 
		WHERE type = 'PAYOUT' AND status = 'SUCCESS' 
		AND description LIKE 'PromptPay%'
	`)
	if err != nil {
		log.Fatal(err)
	}
	defer rows.Close()

	omiseSecret := os.Getenv("OMISE_SECRET_KEY")
	if omiseSecret == "" {
		log.Fatal("❌ OMISE_SECRET_KEY not found in .env")
	}

	for rows.Next() {
		var txID, refID string
		var amount int64
		rows.Scan(&txID, &refID, &amount)

		fmt.Printf("🔄 Syncing Tx %s (฿%.2f) to Omise...\n", txID, float64(amount)/100)

		// Call Omise Transfer API
		client := &http.Client{}
		url := "https://api.omise.co/transfers"
		form := url_pkg.Values{}
		form.Set("amount", fmt.Sprintf("%d", amount))
		
		req, _ := http.NewRequest("POST", url, strings.NewReader(form.Encode()))
		req.SetBasicAuth(omiseSecret, "")
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
		// Use reference_id as idempotency key to prevent double transfers
		req.Header.Set("Omise-Idempotency-Key", refID)

		resp, err := client.Do(req)
		if err != nil {
			fmt.Printf("  ❌ Network Error: %v\n", err)
			continue
		}
		defer resp.Body.Close()
		fmt.Printf("  ✅ Omise Response: %d\n", resp.StatusCode)
	}

	fmt.Println("🏁 All tasks completed.")
}
