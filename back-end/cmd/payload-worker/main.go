package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"math"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/bytedance/sonic"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/joho/godotenv"
	"github.com/redis/go-redis/v9"
)

type OutboxEvent struct {
	ID         string
	EventType  string
	Payload    string
	RetryCount int
}

type TransferPayload struct {
	TransactionID string `json:"transaction_id"`
	FromWallet    string `json:"from_wallet"`
	ToWallet      string `json:"to_wallet"`
	Amount        int64  `json:"amount"`
	Currency      string `json:"currency"`
}

type NotificationPayload struct {
	UserID  string `json:"user_id"`
	Title   string `json:"title"`
	Body    string `json:"body"`
	Channel string `json:"channel"`
}

type WorkerConfig struct {
	BatchSize    int
	PollInterval time.Duration
	MaxRetries   int
}

type PayloadWorker struct {
	db     *sql.DB
	rdb    *redis.Client
	config WorkerConfig
}

func NewPayloadWorker(db *sql.DB, rdb *redis.Client, config WorkerConfig) *PayloadWorker {
	return &PayloadWorker{
		db:     db,
		rdb:    rdb,
		config: config,
	}
}

func (w *PayloadWorker) Run(ctx context.Context) error {
	log.Println("🚀 Go Payload Worker starting...")
	log.Printf("Configuration - BatchSize: %d, PollInterval: %v, MaxRetries: %d",
		w.config.BatchSize, w.config.PollInterval, w.config.MaxRetries)

	failCount := 0

	for {
		select {
		case <-ctx.Done():
			log.Println("Stopping worker loop...")
			return nil
		default:
			processed, err := w.processOutboxBatch(ctx)
			if err != nil {
				failCount++
				// Exponential backoff: 1s, 2s, 4s, 8s, max 30s
				backoffSecs := int(math.Min(math.Pow(2, float64(failCount)), 30))
				log.Printf("❌ Error processing batch (failCount: %d). Backing off for %ds: %v", failCount, backoffSecs, err)

				if failCount > 3 {
					log.Println("Failures persisting. Checking database connection...")
					if err := w.db.PingContext(ctx); err != nil {
						log.Printf("DB connection ping failed: %v", err)
					}
				}

				select {
				case <-ctx.Done():
					return nil
				case <-time.After(time.Duration(backoffSecs) * time.Second):
				}
				continue
			}

			failCount = 0 // Reset fail count on success

			if processed == 0 {
				select {
				case <-ctx.Done():
					return nil
				case <-time.After(w.config.PollInterval):
				}
			}
			// If processed > 0, run again immediately without sleep to drain queue
		}
	}
}

func (w *PayloadWorker) processOutboxBatch(ctx context.Context) (int, error) {
	// Start transaction for FOR UPDATE SKIP LOCKED
	tx, err := w.db.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
	if err != nil {
		return 0, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Fetch pending events matching Rust query
	rows, err := tx.QueryContext(ctx, `
		SELECT id::text, event_type, payload::text, retry_count
		FROM transaction_outbox
		WHERE status = 'PENDING' AND retry_count < $1
		ORDER BY created_at ASC
		LIMIT $2
		FOR UPDATE SKIP LOCKED
	`, w.config.MaxRetries, w.config.BatchSize)
	if err != nil {
		return 0, fmt.Errorf("query transaction_outbox failed: %w", err)
	}

	var events []OutboxEvent
	for rows.Next() {
		var ev OutboxEvent
		if err := rows.Scan(&ev.ID, &ev.EventType, &ev.Payload, &ev.RetryCount); err != nil {
			rows.Close()
			return 0, fmt.Errorf("scan outbox event failed: %w", err)
		}
		events = append(events, ev)
	}
	rows.Close()

	if len(events) == 0 {
		return 0, nil
	}

	start := time.Now()
	processed := 0
	failed := 0

	for _, ev := range events {
		err := w.processSingleEvent(ctx, &ev)
		if err == nil {
			// Mark as processed
			_, err = tx.ExecContext(ctx, `
				UPDATE transaction_outbox 
				SET status = 'PROCESSED', processed_at = NOW() 
				WHERE id = $1::uuid
			`, ev.ID)
			if err != nil {
				return processed, fmt.Errorf("failed to mark event as processed: %w", err)
			}
			processed++
		} else {
			log.Printf("Failed to process event_id: %s, error: %v", ev.ID, err)
			newRetry := ev.RetryCount + 1
			var newStatus string
			if newRetry >= w.config.MaxRetries {
				newStatus = "FAILED"
			} else {
				newStatus = "PENDING"
			}

			// Update retry count and error message
			_, err = tx.ExecContext(ctx, `
				UPDATE transaction_outbox 
				SET retry_count = $1, last_attempt_at = NOW(), error_message = $2, status = $3 
				WHERE id = $4::uuid
			`, newRetry, err.Error(), newStatus, ev.ID)
			if err != nil {
				return processed, fmt.Errorf("failed to update event retry status: %w", err)
			}
			failed++
		}
	}

	if err := tx.Commit(); err != nil {
		return 0, fmt.Errorf("failed to commit outbox transaction: %w", err)
	}

	log.Printf("Batch processed: %d succeeded, %d failed in %v", processed, failed, time.Since(start))
	return processed, nil
}

func (w *PayloadWorker) processSingleEvent(ctx context.Context, ev *OutboxEvent) error {
	switch ev.EventType {
	case "TRANSFER_COMPLETED", "TRANSFER_INITIATED":
		var transfer TransferPayload
		if err := sonic.UnmarshalString(ev.Payload, &transfer); err != nil {
			return fmt.Errorf("sonic unmarshal TransferPayload failed: %w", err)
		}

		channel := fmt.Sprintf("wallet:%s", transfer.FromWallet)
		if err := w.rdb.Publish(ctx, channel, ev.Payload).Err(); err != nil {
			return fmt.Errorf("redis publish failed: %w", err)
		}

		log.Printf("Transfer event processed (event_id=%s, tx_id=%s)", ev.ID, transfer.TransactionID)

	case "PROMPTPAY_PAYOUT", "PAYOUT_REQUESTED", "PAYOUT_INITIATED":
		if err := w.rdb.Publish(ctx, "payout:updates", ev.Payload).Err(); err != nil {
			return fmt.Errorf("redis publish failed: %w", err)
		}
		log.Printf("Payout event processed (event_id=%s, type=%s)", ev.ID, ev.EventType)

	case "NOTIFICATION":
		var notification NotificationPayload
		if err := sonic.UnmarshalString(ev.Payload, &notification); err != nil {
			return fmt.Errorf("sonic unmarshal NotificationPayload failed: %w", err)
		}

		var redisList string
		switch notification.Channel {
		case "push":
			redisList = "notifications:push"
		case "sms":
			redisList = "notifications:sms"
		case "email":
			redisList = "notifications:email"
		default:
			log.Printf("⚠️ Unknown notification channel: %s, skipping", notification.Channel)
			return nil
		}

		if err := w.rdb.LPush(ctx, redisList, ev.Payload).Err(); err != nil {
			return fmt.Errorf("redis lpush failed: %w", err)
		}
		log.Printf("Notification queued (event_id=%s, user_id=%s, channel=%s)", ev.ID, notification.UserID, notification.Channel)

	case "WITHDRAWAL_COMPLETED":
		if err := w.rdb.Publish(ctx, "balance:updates", ev.Payload).Err(); err != nil {
			return fmt.Errorf("redis publish failed: %w", err)
		}
		log.Printf("Withdrawal event processed (event_id=%s)", ev.ID)

	default:
		log.Printf("⚠️ Unknown event type, skipping: %s", ev.EventType)
	}

	return nil
}

func main() {
	_ = godotenv.Load()

	// 1. DB Connect options
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://postgres:postgres@localhost/paycif"
	}

	// For pgx connection: we must use pgx simple protocol.
	// Since we use database/sql with stdlib pgx, the connection string parameters:
	// "default_query_exec_mode=simple_protocol" or "default_query_exec_mode=cache_describe" (pgx v5)
	// We append simple protocol query parameter to database URL if not present.
	// We will parse it and append default_query_exec_mode=simple_protocol
	dbURL = appendSimpleProtocol(dbURL)

	log.Printf("Connecting to repository...")
	db, err := sql.Open("pgx", dbURL)
	if err != nil {
		log.Fatalf("Failed to open DB: %v", err)
	}
	defer db.Close()

	db.SetMaxOpenConns(5)
	db.SetMaxIdleConns(1)
	db.SetConnMaxLifetime(3 * time.Minute)

	if err := db.Ping(); err != nil {
		log.Fatalf("Failed to ping DB: %v", err)
	}
	log.Println("✅ Database connection established")

	// 2. Redis Connection
	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		redisURL = "redis://localhost:6379"
	}
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Fatalf("Failed to parse Redis URL: %v", err)
	}
	rdb := redis.NewClient(opt)
	defer rdb.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatalf("Failed to ping Redis: %v", err)
	}
	log.Println("✅ Redis connection established")

	// 3. Worker Configurations
	batchSize := 100
	if bsStr := os.Getenv("BATCH_SIZE"); bsStr != "" {
		if val, err := strconv.Atoi(bsStr); err == nil {
			batchSize = val
		}
	}
	pollInterval := 100 * time.Millisecond
	if piStr := os.Getenv("POLL_INTERVAL_MS"); piStr != "" {
		if val, err := strconv.Atoi(piStr); err == nil {
			pollInterval = time.Duration(val) * time.Millisecond
		}
	}

	config := WorkerConfig{
		BatchSize:    batchSize,
		PollInterval: pollInterval,
		MaxRetries:   3,
	}

	worker := NewPayloadWorker(db, rdb, config)

	// Context for clean shutdown
	runCtx, runCancel := context.WithCancel(context.Background())
	defer runCancel()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigChan
		log.Println("Received termination signal, shutting down payload worker...")
		runCancel()
	}()

	log.Println("⚡ Go SIMD-Sonic Payload Worker v1.0.0 starting...")
	if err := worker.Run(runCtx); err != nil {
		log.Fatalf("Worker execution failed: %v", err)
	}
	log.Println("Shutdown complete.")
}

func appendSimpleProtocol(connURL string) string {
	// pgx uses default_query_exec_mode
	// For Supabase transaction mode, use simple_protocol
	importQueryMode := "default_query_exec_mode=simple_protocol"
	if os.Getenv("USE_PGX_CACHE_DESCRIBE") == "true" {
		importQueryMode = "default_query_exec_mode=cache_describe"
	}

	// Add query parameter
	// Check if already has query parameters
	var delimiter string
	if !strings.Contains(connURL, "default_query_exec_mode=") {
		if strings.Contains(connURL, "?") {
			delimiter = "&"
		} else {
			delimiter = "?"
		}
		connURL = connURL + delimiter + importQueryMode
	}

	// Check if sslmode exists
	if !strings.Contains(connURL, "sslmode=") && !strings.Contains(connURL, "localhost") && !strings.Contains(connURL, "127.0.0.1") {
		connURL = connURL + "&sslmode=require"
	}

	return connURL
}
