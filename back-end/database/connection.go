package database

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib" // pgx driver for better Supabase support
)

var DB *sql.DB

// Connect initializes the database connection using DATABASE_URL env var.
func Connect() error {
	connStr := os.Getenv("DATABASE_URL")
	// Verify connection string presence
	if connStr == "" {
		return fmt.Errorf("DATABASE_URL environment variable is not set")
	}

	// 🛡️ Supabase Compatibility:
	// pgx handles SSL and IPv6 much better than lib/pq.
	// We add default_query_exec_mode=cache_describe for Supabase Pooler compatibility.
	if !strings.Contains(connStr, "sslmode=") {
		if strings.Contains(connStr, "?") {
			connStr += "&sslmode=require"
		} else {
			connStr += "?sslmode=require"
		}
	}
	if !strings.Contains(connStr, "default_query_exec_mode=") {
		if strings.Contains(connStr, "?") {
			connStr += "&default_query_exec_mode=cache_describe"
		} else {
			connStr += "?default_query_exec_mode=cache_describe"
		}
	}

	// Logging connection attempt (Redacted for security)
	log.Printf("Connecting to database with pgx driver...")

	// Use "pgx" driver name which corresponds to github.com/jackc/pgx/v5/stdlib
	var err error
	DB, err = sql.Open("pgx", connStr)
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

	// --- Auto-Migration: Ensure necessary tables exist ---
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

	CREATE TABLE IF NOT EXISTS audit_logs (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		user_id UUID NOT NULL,
		action VARCHAR(100) NOT NULL,
		resource_type VARCHAR(50) NOT NULL,
		resource_id VARCHAR(100),
		metadata JSONB,
		request_id VARCHAR(100),
		ip_address VARCHAR(50),
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_audit_user_action ON audit_logs(user_id, action);
	CREATE INDEX IF NOT EXISTS idx_audit_created_at ON audit_logs(created_at);
	`
	if _, err := DB.Exec(query); err != nil {
		log.Printf("⚠️ Warning: Failed to ensure system tables exist: %v\n", err)
	} else {
		log.Println("✅ Verified system tables (outbox, audit_logs).")
	}
	// --------------------------------------------------------

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

