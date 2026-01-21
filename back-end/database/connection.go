package database

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	_ "github.com/lib/pq" // PostgreSQL driver
)

var DB *sql.DB

// Connect initializes the database connection using DATABASE_URL env var.
func Connect() error {
	connStr := os.Getenv("DATABASE_URL")
	if connStr == "" {
		return fmt.Errorf("DATABASE_URL environment variable is not set")
	}

	// FIX: Supabase "Transaction Mode" (Port 6543) does not support prepared statements
	// used by lib/pq. We must use "Session Mode" (Port 5432) for this Go backend.
	// We automatically patch the port if it is set to 6543.
	if strings.Contains(connStr, ":6543") {
		connStr = strings.Replace(connStr, ":6543", ":5432", 1)
		log.Println("Patch: Switched to Session Mode (Port 5432) for lib/pq compatibility")
	}

	var err error
	DB, err = sql.Open("postgres", connStr)
	if err != nil {
		return fmt.Errorf("error opening database: %w", err)
	}

	// Set connection pool settings
	DB.SetMaxOpenConns(25)
	DB.SetMaxIdleConns(5)
	DB.SetConnMaxLifetime(5 * time.Minute)

	// Verify connection
	if err := DB.Ping(); err != nil {
		return fmt.Errorf("error connecting to the database: %w", err)
	}

	log.Println("Successfully connected to the database")
	return nil
}

// Close closes the database connection.
func Close() {
	if DB != nil {
		DB.Close()
	}
}
