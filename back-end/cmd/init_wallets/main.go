package main

import (
	"log"
	"paysif/database"

	"github.com/google/uuid"
	_ "github.com/joho/godotenv/autoload"
)

func main() {
	if err := database.Connect(); err != nil {
		log.Fatalf("Failed to connect to DB: %v", err)
	}
	defer database.Close()

	// 1. Get All Users
	rows, err := database.DB.Query("SELECT id FROM profiles")
	if err != nil {
		log.Fatal(err)
	}
	defer rows.Close()

	for rows.Next() {
		var userID uuid.UUID
		if err := rows.Scan(&userID); err != nil {
			log.Println("Error scanning user:", err)
			continue
		}

		// 2. Check if THB Wallet exists
		var exists bool
		err = database.DB.QueryRow("SELECT EXISTS(SELECT 1 FROM wallets WHERE profile_id = $1 AND currency = 'THB')", userID).Scan(&exists)
		if err != nil {
			log.Println("Error checking wallet:", err)
			continue
		}

		if !exists {
			// 3. Create Wallet
			walletID := uuid.New()
			_, err := database.DB.Exec(`
				INSERT INTO wallets (id, profile_id, currency, balance, status, created_at, updated_at)
				VALUES ($1, $2, 'THB', 500000, 'ACTIVE', NOW(), NOW()) -- Initial 5,000 THB for testing
			`, walletID, userID)
			
			if err != nil {
				log.Printf("Failed to create wallet for user %s: %v\n", userID, err)
			} else {
				log.Printf("✅ Created THB Wallet for User %s with 5,000 THB\n", userID)
			}
		} else {
			log.Printf("ℹ️ User %s already has a wallet.\n", userID)
		}
	}
}
