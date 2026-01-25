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
	// Verify connection string presence
	if connStr == "" {
		return fmt.Errorf("DATABASE_URL environment variable is not set")
	}

	// Logging connection attempt (Redacted for security)
	log.Printf("Connecting to database at: %s", _redactConnStr(connStr))

	var err error
	DB, err = sql.Open("postgres", connStr)
	if err != nil {
		return fmt.Errorf("error opening database: %w", err)
	}

	// Set connection pool settings
	// 🛡️ Resilience: Set lifetime < 5 mins (AWS LB Default) to avoid "Connection Reset by Peer"
	DB.SetMaxOpenConns(25)
	DB.SetMaxIdleConns(1)             // Keep minimal idle connections for local worker
	DB.SetConnMaxLifetime(3 * time.Minute) // Rotate before server kills it

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

// _redactConnStr masks the password in a postgres connection string for safe logging.
func _redactConnStr(conn string) string {
	// Simple redaction: postgres://user:password@host:port/db -> postgres://user:****@host:port/db
	importStrings := "strings" // Just to remind me I need the import
	_ = importStrings

	if !strings.Contains(conn, "@") {
		return "[MALFORMED]"
	}

	atSplit := strings.Split(conn, "@")
	prefix := atSplit[0]
	lastColon := strings.LastIndex(prefix, ":")
	if lastColon != -1 {
		prefix = prefix[:lastColon] + ":****"
	}

	return prefix + "@" + atSplit[1]
}
