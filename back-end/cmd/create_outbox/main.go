package main

import (
	"log"
	"paysif/database"

	_ "github.com/joho/godotenv/autoload"
)

func main() {
	if err := database.Connect(); err != nil {
		log.Fatalf("Failed to connect to DB: %v", err)
	}
	defer database.Close()

	query := `
	CREATE TABLE IF NOT EXISTS transaction_outbox (
		id UUID PRIMARY KEY,
		transaction_id UUID NOT NULL,
		event_type VARCHAR(50) NOT NULL,
		payload JSONB NOT NULL,
		status VARCHAR(20) DEFAULT 'PENDING',
		created_at TIMESTAMPTZ DEFAULT NOW(),
		processed_at TIMESTAMPTZ
	);
	
	CREATE INDEX IF NOT EXISTS idx_outbox_status ON transaction_outbox(status);
	`

	_, err := database.DB.Exec(query)
	if err != nil {
		log.Fatalf("Failed to create table: %v", err)
	}

	log.Println("✅ Table 'transaction_outbox' created successfully.")
}
