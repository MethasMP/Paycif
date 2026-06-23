package repository

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
	DB.SetMaxOpenConns(15)
	DB.SetMaxIdleConns(5)                  // Keep some idle connections for the worker
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
