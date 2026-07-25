package main

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	pb "paysif/internal/adapter/grpc/pb"

	"github.com/google/uuid"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/joho/godotenv"
	"github.com/redis/go-redis/v9"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/keepalive"
	"google.golang.org/grpc/status"
)

const (
	MaxDailyLimit       = 20000.0 // ฿20,000
	MaxTransactionLimit = 5000.0  // ฿5,000
)

// UserLimitEntry is cache-line aligned and thread-safe via atomics
type UserLimitEntry struct {
	DailyTotal int64    // represented in minor units (satangs/cents)
	Date       int32    // YYYYMMDD representation
	LastSynced int64    // Unix nanosecond timestamp
	Hydrated   int32    // 0 = false, 1 = true
	_          [40]byte // Padding to fit exactly 64 bytes (Cache Line alignment)
}

func (e *UserLimitEntry) IsStale(maxAge time.Duration) bool {
	lastSynced := atomic.LoadInt64(&e.LastSynced)
	return time.Since(time.Unix(0, lastSynced)) > maxAge
}

func (e *UserLimitEntry) IsDifferentDay(today int32) bool {
	date := atomic.LoadInt32(&e.Date)
	return date != today
}

func getTodayInt() int32 {
	t := time.Now().UTC()
	return int32(t.Year()*10000 + int(t.Month())*100 + t.Day())
}

// ILimitCache defines the interface for limit caching
type ILimitCache interface {
	CheckTransaction(ctx context.Context, userID uuid.UUID, amount int64) (bool, int64, string, error)
	ReleaseLimit(userID uuid.UUID, amount int64)
	PreHydrate(ctx context.Context) error
	GetLimits(ctx context.Context, userID uuid.UUID) (currentDaily, maxDaily, maxTransaction, remaining int64, err error)
	ApplyRemoteIncrement(userID uuid.UUID, amount int64)
}

// ShardedLimitCache implements ILimitCache
type ShardedLimitCache struct {
	shards [32]*LimitShard
	db     *sql.DB
	maxAge time.Duration
}

type LimitShard struct {
	mu   sync.RWMutex
	data map[uuid.UUID]*UserLimitEntry
}

func NewShardedLimitCache(db *sql.DB, maxAge time.Duration) *ShardedLimitCache {
	c := &ShardedLimitCache{
		db:     db,
		maxAge: maxAge,
	}
	for i := 0; i < 32; i++ {
		c.shards[i] = &LimitShard{
			data: make(map[uuid.UUID]*UserLimitEntry),
		}
	}
	return c
}

func (c *ShardedLimitCache) getShard(u uuid.UUID) *LimitShard {
	var hash byte
	for i := 0; i < 16; i++ {
		hash ^= u[i]
	}
	return c.shards[int(hash)%32]
}

func (c *ShardedLimitCache) CheckTransaction(ctx context.Context, userID uuid.UUID, amount int64) (bool, int64, string, error) {
	// 1. Check transaction limit (amount in satang)
	maxTxSatang := int64(MaxTransactionLimit * 100)
	if amount > maxTxSatang {
		return false, 0, fmt.Sprintf("Amount exceeds transaction limit of %.2f", MaxTransactionLimit), nil
	}

	today := getTodayInt()
	shard := c.getShard(userID)
	maxDailySatang := int64(MaxDailyLimit * 100)

	// 2. Fast-path: read lock to fetch pointer
	shard.mu.RLock()
	entry, exists := shard.data[userID]
	shard.mu.RUnlock()

	if exists && atomic.LoadInt32(&entry.Hydrated) == 1 && !entry.IsStale(c.maxAge) {
		// CAS loop for atomic checking and reservation
		for {
			currentTotal := atomic.LoadInt64(&entry.DailyTotal)
			currentDate := atomic.LoadInt32(&entry.Date)

			if currentDate != today {
				// Reset balance for new day atomically
				if atomic.CompareAndSwapInt32(&entry.Date, currentDate, today) {
					atomic.StoreInt64(&entry.DailyTotal, 0)
					currentTotal = 0
				} else {
					continue // Conflict, retry
				}
			}

			if currentTotal+amount > maxDailySatang {
				remaining := maxDailySatang - currentTotal
				if remaining < 0 {
					remaining = 0
				}
				return false, remaining, fmt.Sprintf("Daily limit exceeded. Remaining: %.2f", float64(remaining)/100.0), nil
			}

			if atomic.CompareAndSwapInt64(&entry.DailyTotal, currentTotal, currentTotal+amount) {
				atomic.StoreInt64(&entry.LastSynced, time.Now().UnixNano())
				remaining := maxDailySatang - (currentTotal + amount)
				if remaining < 0 {
					remaining = 0
				}
				return true, remaining, "", nil
			}
		}
	}

	// 3. Slow-path: Hydrate from DB
	usage, err := c.hydrateFromDB(ctx, userID)
	if err != nil {
		return false, 0, "", err
	}

	// Acquire write lock to insert new pointer or update existing
	shard.mu.Lock()
	entry, exists = shard.data[userID]
	if !exists {
		entry = &UserLimitEntry{
			DailyTotal: usage,
			Date:       today,
			LastSynced: time.Now().UnixNano(),
			Hydrated:   1,
		}
		shard.data[userID] = entry
	} else {
		// Update existing pointer fields atomically
		atomic.StoreInt64(&entry.DailyTotal, usage)
		atomic.StoreInt32(&entry.Date, today)
		atomic.StoreInt64(&entry.LastSynced, time.Now().UnixNano())
		atomic.StoreInt32(&entry.Hydrated, 1)
	}
	shard.mu.Unlock()

	// Run check and reservation again on the pointer
	for {
		currentTotal := atomic.LoadInt64(&entry.DailyTotal)
		currentDate := atomic.LoadInt32(&entry.Date)

		if currentDate != today {
			if atomic.CompareAndSwapInt32(&entry.Date, currentDate, today) {
				atomic.StoreInt64(&entry.DailyTotal, 0)
				currentTotal = 0
			} else {
				continue
			}
		}

		if currentTotal+amount > maxDailySatang {
			remaining := maxDailySatang - currentTotal
			if remaining < 0 {
				remaining = 0
			}
			return false, remaining, fmt.Sprintf("Daily limit exceeded. Remaining: %.2f", float64(remaining)/100.0), nil
		}

		if atomic.CompareAndSwapInt64(&entry.DailyTotal, currentTotal, currentTotal+amount) {
			atomic.StoreInt64(&entry.LastSynced, time.Now().UnixNano())
			remaining := maxDailySatang - (currentTotal + amount)
			if remaining < 0 {
				remaining = 0
			}
			return true, remaining, "", nil
		}
	}
}

func (c *ShardedLimitCache) ReleaseLimit(userID uuid.UUID, amount int64) {
	shard := c.getShard(userID)
	shard.mu.RLock()
	entry, exists := shard.data[userID]
	shard.mu.RUnlock()

	if exists {
		for {
			currentTotal := atomic.LoadInt64(&entry.DailyTotal)
			newTotal := currentTotal - amount
			if newTotal < 0 {
				newTotal = 0
			}
			if atomic.CompareAndSwapInt64(&entry.DailyTotal, currentTotal, newTotal) {
				atomic.StoreInt64(&entry.LastSynced, time.Now().UnixNano())
				break
			}
		}
	}
}

func (c *ShardedLimitCache) ApplyRemoteIncrement(userID uuid.UUID, amount int64) {
	shard := c.getShard(userID)
	today := getTodayInt()

	shard.mu.RLock()
	entry, exists := shard.data[userID]
	shard.mu.RUnlock()

	if exists {
		for {
			currentTotal := atomic.LoadInt64(&entry.DailyTotal)
			currentDate := atomic.LoadInt32(&entry.Date)

			newTotal := currentTotal + amount
			if currentDate != today {
				newTotal = amount // Reset to only the new transaction amount if day has changed
			}

			// We need to write back the new balance and date atomically
			if currentDate != today {
				if atomic.CompareAndSwapInt32(&entry.Date, currentDate, today) {
					atomic.StoreInt64(&entry.DailyTotal, newTotal)
					atomic.StoreInt64(&entry.LastSynced, time.Now().UnixNano())
					break
				}
				continue
			}

			if atomic.CompareAndSwapInt64(&entry.DailyTotal, currentTotal, newTotal) {
				atomic.StoreInt64(&entry.LastSynced, time.Now().UnixNano())
				break
			}
		}
	} else {
		shard.mu.Lock()
		// Double check
		entry, exists = shard.data[userID]
		if !exists {
			entry = &UserLimitEntry{
				DailyTotal: amount,
				Date:       today,
				LastSynced: time.Now().UnixNano(),
				Hydrated:   0, // Not hydrated from DB, but contains state
			}
			shard.data[userID] = entry
		} else {
			// Exist now, release lock and update atomically
			shard.mu.Unlock()
			c.ApplyRemoteIncrement(userID, amount)
			return
		}
		shard.mu.Unlock()
	}
}

func (c *ShardedLimitCache) GetLimits(ctx context.Context, userID uuid.UUID) (currentDaily, maxDaily, maxTransaction, remaining int64, err error) {
	today := getTodayInt()
	shard := c.getShard(userID)

	shard.mu.RLock()
	entry, exists := shard.data[userID]
	shard.mu.RUnlock()

	var usage int64
	if exists && atomic.LoadInt32(&entry.Hydrated) == 1 && !entry.IsStale(c.maxAge) {
		currentDate := atomic.LoadInt32(&entry.Date)
		if currentDate != today {
			// Try to reset day atomically
			if atomic.CompareAndSwapInt32(&entry.Date, currentDate, today) {
				atomic.StoreInt64(&entry.DailyTotal, 0)
			}
		}
		usage = atomic.LoadInt64(&entry.DailyTotal)
	} else {
		usage, err = c.hydrateFromDB(ctx, userID)
		if err != nil {
			return 0, 0, 0, 0, err
		}

		shard.mu.Lock()
		entry, exists = shard.data[userID]
		if !exists {
			entry = &UserLimitEntry{
				DailyTotal: usage,
				Date:       today,
				LastSynced: time.Now().UnixNano(),
				Hydrated:   1,
			}
			shard.data[userID] = entry
		} else {
			atomic.StoreInt64(&entry.DailyTotal, usage)
			atomic.StoreInt32(&entry.Date, today)
			atomic.StoreInt64(&entry.LastSynced, time.Now().UnixNano())
			atomic.StoreInt32(&entry.Hydrated, 1)
		}
		shard.mu.Unlock()
	}

	maxDailySatang := int64(MaxDailyLimit * 100)
	maxTxSatang := int64(MaxTransactionLimit * 100)
	rem := maxDailySatang - usage
	if rem < 0 {
		rem = 0
	}

	return usage, maxDailySatang, maxTxSatang, rem, nil
}

func (c *ShardedLimitCache) hydrateFromDB(ctx context.Context, userID uuid.UUID) (int64, error) {
	if c.db == nil {
		return 0, nil
	}

	var total sql.NullInt64
	query := `
		SELECT SUM(ABS(amount))
		FROM ledger_entries
		WHERE account_id IN (SELECT id FROM payment_accounts WHERE profile_id = $1::uuid)
		  AND amount < 0
		  AND created_at >= CURRENT_DATE
	`
	err := c.db.QueryRowContext(ctx, query, userID).Scan(&total)
	if err != nil {
		log.Printf("⚠️ Failed to hydrate limits from DB for user %s: %v", userID, err)
		return 0, err
	}

	if !total.Valid {
		return 0, nil
	}
	return total.Int64, nil
}

func (c *ShardedLimitCache) PreHydrate(ctx context.Context) error {
	if c.db == nil {
		return errors.New("DB not connected")
	}

	query := `
		SELECT w.profile_id, SUM(ABS(le.amount)) 
		FROM ledger_entries le
		JOIN payment_accounts w ON le.account_id = w.id
		WHERE le.created_at >= CURRENT_DATE
		GROUP BY w.profile_id
		ORDER BY COUNT(*) DESC
		LIMIT 5000
	`
	rows, err := c.db.QueryContext(ctx, query)
	if err != nil {
		return err
	}
	defer rows.Close()

	today := getTodayInt()
	count := 0
	for rows.Next() {
		var profileID uuid.UUID
		var total int64
		if err := rows.Scan(&profileID, &total); err != nil {
			return err
		}

		shard := c.getShard(profileID)
		shard.mu.Lock()
		shard.data[profileID] = &UserLimitEntry{
			DailyTotal: total,
			Date:       today,
			LastSynced: time.Now().UnixNano(),
			Hydrated:   1,
		}
		shard.mu.Unlock()
		count++
	}

	log.Printf("🧠 Pre-hydrated %d active users into Accounting Core limit cache", count)
	return nil
}

// ITransferExecutor defines transfer execution logic
type ITransferExecutor interface {
	Execute(ctx context.Context, req *pb.TransferRequest) (*pb.TransferResponse, error)
	Validate(ctx context.Context, req *pb.TransferRequest) (bool, string, error)
}

// TransferExecutor implements ITransferExecutor using composition
type TransferExecutor struct {
	db         *sql.DB
	limitCache ILimitCache
}

func NewTransferExecutor(db *sql.DB, limitCache ILimitCache) *TransferExecutor {
	return &TransferExecutor{
		db:         db,
		limitCache: limitCache,
	}
}

func (t *TransferExecutor) Execute(ctx context.Context, req *pb.TransferRequest) (*pb.TransferResponse, error) {
	fromWallet, err := uuid.Parse(req.FromWalletId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid from_wallet_id: %v", err)
	}
	toWallet, err := uuid.Parse(req.ToWalletId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid to_wallet_id: %v", err)
	}
	userUUID, err := uuid.Parse(req.UserId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid user_id: %v", err)
	}

	// Begin SQL transaction with SERIALIZABLE isolation level
	tx, err := t.db.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelSerializable})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to start transaction: %v", err)
	}
	defer tx.Rollback()

	// 1. Idempotency Check
	var existingID string
	err = tx.QueryRowContext(ctx, "SELECT id::text FROM transactions WHERE reference_id = $1", req.ReferenceId).Scan(&existingID)
	if err == nil {
		// Idempotent hit: return existing transaction details
		var senderBal, receiverBal sql.NullInt64
		err = tx.QueryRowContext(ctx, `
			SELECT 
				(SELECT balance_after FROM ledger_entries WHERE transaction_id = $1::uuid AND amount < 0 LIMIT 1),
				(SELECT balance_after FROM ledger_entries WHERE transaction_id = $1::uuid AND amount > 0 LIMIT 1)
		`, existingID).Scan(&senderBal, &receiverBal)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "failed to fetch idempotent balances: %v", err)
		}

		return &pb.TransferResponse{
			Success:              true,
			TransactionId:        existingID,
			ErrorCode:            "",
			ErrorMessage:         "Already processed (idempotent)",
			SenderBalanceAfter:   senderBal.Int64,
			ReceiverBalanceAfter: receiverBal.Int64,
		}, nil
	} else if !errors.Is(err, sql.ErrNoRows) {
		return nil, status.Errorf(codes.Internal, "idempotency check error: %v", err)
	}

	// 2. Verify payment account ownership
	var ownerID uuid.UUID
	err = tx.QueryRowContext(ctx, "SELECT profile_id FROM payment_accounts WHERE id = $1", fromWallet).Scan(&ownerID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return &pb.TransferResponse{
				Success:      false,
				ErrorCode:    "UNAUTHORIZED",
				ErrorMessage: "Sender payment account not found",
			}, nil
		}
		return nil, status.Errorf(codes.Internal, "account ownership fetch failed: %v", err)
	}

	if ownerID != userUUID {
		return &pb.TransferResponse{
			Success:      false,
			ErrorCode:    "UNAUTHORIZED",
			ErrorMessage: "Account does not belong to user",
		}, nil
	}

	// 3. Limit check (optimistically reserved)
	allowed, _, limitMsg, err := t.limitCache.CheckTransaction(ctx, userUUID, req.Amount)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "limit check error: %v", err)
	}
	if !allowed {
		return &pb.TransferResponse{
			Success:      false,
			ErrorCode:    "LIMIT_EXCEEDED",
			ErrorMessage: limitMsg,
		}, nil
	}

	// 4. Double entry logic
	senderBalance, receiverBalance, err := t.executeDoubleEntry(ctx, tx, fromWallet, toWallet, req.Amount, req.Currency)
	if err != nil {
		// Roll back and release limit
		tx.Rollback()
		t.limitCache.ReleaseLimit(userUUID, req.Amount)

		log.Printf("Transfer double entry failed: %v", err)
		return &pb.TransferResponse{
			Success:      false,
			ErrorCode:    "FAILED",
			ErrorMessage: err.Error(),
		}, nil
	}

	if err := tx.Commit(); err != nil {
		t.limitCache.ReleaseLimit(userUUID, req.Amount)
		return nil, status.Errorf(codes.Internal, "failed to commit transaction: %v", err)
	}

	return &pb.TransferResponse{
		Success:              true,
		TransactionId:        req.ReferenceId, // or transaction ID
		SenderBalanceAfter:   senderBalance,
		ReceiverBalanceAfter: receiverBalance,
	}, nil
}

func (t *TransferExecutor) executeDoubleEntry(ctx context.Context, tx *sql.Tx, from, to uuid.UUID, amount int64, currency string) (senderBal, receiverBal int64, err error) {
	// Lock sender
	var sBal int64
	var sCurr, sStatus string
	err = tx.QueryRowContext(ctx, "SELECT balance, currency::text, status FROM payment_accounts WHERE id = $1 FOR UPDATE", from).Scan(&sBal, &sCurr, &sStatus)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return 0, 0, errors.New("Sender payment account not found")
		}
		return 0, 0, err
	}

	if sCurr != currency {
		return 0, 0, errors.New("Currency mismatch")
	}
	if sStatus != "ACTIVE" {
		return 0, 0, errors.New("Sender account not active")
	}
	if sBal < amount {
		return 0, 0, errors.New("Insufficient funds")
	}

	// Lock receiver
	var rBal int64
	var rCurr string
	err = tx.QueryRowContext(ctx, "SELECT balance, currency::text FROM payment_accounts WHERE id = $1 FOR UPDATE", to).Scan(&rBal, &rCurr)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return 0, 0, errors.New("Receiver payment account not found")
		}
		return 0, 0, err
	}

	if rCurr != currency {
		return 0, 0, errors.New("Receiver currency mismatch")
	}

	newSBal := sBal - amount
	newRBal := rBal + amount

	// Update accounts
	_, err = tx.ExecContext(ctx, "UPDATE payment_accounts SET balance = $1, updated_at = NOW() WHERE id = $2", newSBal, from)
	if err != nil {
		return 0, 0, err
	}

	_, err = tx.ExecContext(ctx, "UPDATE payment_accounts SET balance = $1, updated_at = NOW() WHERE id = $2", newRBal, to)
	if err != nil {
		return 0, 0, err
	}

	// Create transaction record
	txnID := uuid.New()
	_, err = tx.ExecContext(ctx, "INSERT INTO transactions (id, reference_id, description, settlement_status) VALUES ($1, $2, $3, 'SETTLED')",
		txnID, fmt.Sprintf("transfer_%s", txnID), "Transfer")
	if err != nil {
		return 0, 0, err
	}

	// Create ledger entries
	_, err = tx.ExecContext(ctx, "INSERT INTO ledger_entries (id, transaction_id, account_id, amount, balance_after) VALUES ($1, $2, $3, $4, $5)",
		uuid.New(), txnID, from, -amount, newSBal)
	if err != nil {
		return 0, 0, err
	}

	_, err = tx.ExecContext(ctx, "INSERT INTO ledger_entries (id, transaction_id, account_id, amount, balance_after) VALUES ($1, $2, $3, $4, $5)",
		uuid.New(), txnID, to, amount, newRBal)
	if err != nil {
		return 0, 0, err
	}

	// Ledger integrity check
	var sum int64
	err = tx.QueryRowContext(ctx, "SELECT COALESCE(SUM(amount), 0) FROM ledger_entries WHERE transaction_id = $1", txnID).Scan(&sum)
	if err != nil {
		return 0, 0, err
	}
	if sum != 0 {
		return 0, 0, errors.New("Ledger integrity check failed")
	}

	return newSBal, newRBal, nil
}

func (t *TransferExecutor) Validate(ctx context.Context, req *pb.TransferRequest) (bool, string, error) {
	fromWallet, err := uuid.Parse(req.FromWalletId)
	if err != nil {
		return false, "", err
	}
	userUUID, err := uuid.Parse(req.UserId)
	if err != nil {
		return false, "", err
	}

	var ownerID uuid.UUID
	err = t.db.QueryRowContext(ctx, "SELECT profile_id FROM payment_accounts WHERE id = $1", fromWallet).Scan(&ownerID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return false, "Sender payment account not found", nil
		}
		return false, "", err
	}

	if ownerID != userUUID {
		return false, "Unauthorized", nil
	}

	allowed, _, limitMsg, err := t.limitCache.CheckTransaction(ctx, userUUID, req.Amount)
	if err != nil {
		return false, "", err
	}

	// Release right away since this is just validation
	t.limitCache.ReleaseLimit(userUUID, req.Amount)

	return allowed, limitMsg, nil
}

// AccountingService gRPC Server Implementation
type AccountingService struct {
	pb.UnimplementedAccountingServiceServer
	db               *sql.DB
	transferExecutor ITransferExecutor
	limitCache       ILimitCache
	rdb              *redis.Client
	startTime        time.Time
}

func NewAccountingService(db *sql.DB, limitCache ILimitCache, rdb *redis.Client) *AccountingService {
	return &AccountingService{
		db:               db,
		transferExecutor: NewTransferExecutor(db, limitCache),
		limitCache:       limitCache,
		rdb:              rdb,
		startTime:        time.Now(),
	}
}

// GRPC Transfer
func (s *AccountingService) Transfer(ctx context.Context, in *pb.TransferRequest) (*pb.TransferResponse, error) {
	resp, err := s.transferExecutor.Execute(ctx, in)
	if err != nil {
		return nil, err
	}

	// Redis Pub/Sub broadcast for limit sync on success
	if resp.Success && s.rdb != nil {
		userID := in.UserId
		amount := in.Amount
		go func() {
			payload := fmt.Sprintf("%s:%d", userID, amount)
			_ = s.rdb.Publish(context.Background(), "user_limit_updates", payload).Err()
		}()
	}

	return resp, nil
}

// GRPC GetBalance
func (s *AccountingService) GetBalance(ctx context.Context, in *pb.BalanceRequest) (*pb.BalanceResponse, error) {
	walletUUID, err := uuid.Parse(in.WalletId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid wallet_id format: %v", err)
	}

	var balance int64
	var currency sql.NullString
	err = s.db.QueryRowContext(ctx, "SELECT balance, currency FROM payment_accounts WHERE id = $1", walletUUID).Scan(&balance, &currency)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return &pb.BalanceResponse{
				Success:      false,
				ErrorMessage: "Payment account not found",
			}, nil
		}
		return nil, status.Errorf(codes.Internal, "database query failed: %v", err)
	}

	return &pb.BalanceResponse{
		Success:  true,
		Balance:  balance,
		Currency: currency.String,
	}, nil
}

// GRPC ValidateTransaction
func (s *AccountingService) ValidateTransaction(ctx context.Context, in *pb.TransferRequest) (*pb.ValidationResponse, error) {
	valid, msg, err := s.transferExecutor.Validate(ctx, in)
	if err != nil {
		return &pb.ValidationResponse{
			IsValid:      false,
			ErrorMessage: err.Error(),
		}, nil
	}

	return &pb.ValidationResponse{
		IsValid:      valid,
		ErrorMessage: msg,
	}, nil
}

// GRPC HealthCheck
func (s *AccountingService) HealthCheck(ctx context.Context, in *pb.HealthRequest) (*pb.HealthResponse, error) {
	var val int
	err := s.db.QueryRowContext(ctx, "SELECT 1").Scan(&val)
	healthy := err == nil

	return &pb.HealthResponse{
		Healthy:       healthy,
		Version:       "3.0-go-ledger",
		UptimeSeconds: int64(time.Since(s.startTime).Seconds()),
	}, nil
}

func main() {
	_ = godotenv.Load()

	log.Println("🚀 Go Accounting Core microservice starting...")

	// Database Connection
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://postgres:postgres@localhost/paycif"
	}
	dbURL = appendSimpleProtocol(dbURL)

	db, err := sql.Open("pgx", dbURL)
	if err != nil {
		log.Fatalf("Failed to open DB: %v", err)
	}
	defer db.Close()

	db.SetMaxOpenConns(15)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(3 * time.Minute)

	if err := db.Ping(); err != nil {
		log.Fatalf("Failed to ping DB: %v", err)
	}
	log.Println("✅ Connected to Postgres database")

	// Redis connection
	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		redisURL = "redis://127.0.0.1:6379/0"
	}
	opt, err := redis.ParseURL(redisURL)
	var rdb *redis.Client
	if err != nil {
		log.Printf("⚠️ Redis parsing failed: %v. Operates without Pub/Sub limit sync.", err)
	} else {
		rdb = redis.NewClient(opt)
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		if err := rdb.Ping(ctx).Err(); err != nil {
			log.Printf("⚠️ Redis ping failed: %v. Operates without Pub/Sub limit sync.", err)
			rdb = nil
		} else {
			log.Println("✅ Connected to Redis")
		}
		cancel()
	}

	limitCache := NewShardedLimitCache(db, 60*time.Second)

	// Pre-hydrate limit cache
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	if err := limitCache.PreHydrate(ctx); err != nil {
		log.Printf("⚠️ LimitCache pre-hydration failed: %v", err)
	}
	cancel()

	// gRPC Service
	service := NewAccountingService(db, limitCache, rdb)

	// Background: Redis Pub/Sub syncing user limits
	if rdb != nil {
		go func() {
			pubsub := rdb.Subscribe(context.Background(), "user_limit_updates")
			defer pubsub.Close()

			log.Println("📡 Subscribed to Redis channel 'user_limit_updates'")
			ch := pubsub.Channel()

			for msg := range ch {
				parts := strings.Split(msg.Payload, ":")
				if len(parts) == 2 {
					uid, err := uuid.Parse(parts[0])
					if err == nil {
						amount, err := strconv.ParseInt(parts[1], 10, 64)
						if err == nil {
							limitCache.ApplyRemoteIncrement(uid, amount)
						}
					}
				}
			}
		}()
	}

	var listener net.Listener
	udsPath := os.Getenv("ACCOUNTING_CORE_UDS")

	// UDS by default to match recommended config, fallback to TCP
	if udsPath == "" {
		udsPath = "/tmp/accounting_core.sock" // Default UDS
	}

	if os.Getenv("ACCOUNTING_CORE_TCP_ONLY") == "true" {
		addr := os.Getenv("ACCOUNTING_CORE_ADDR")
		if addr == "" {
			addr = "0.0.0.0:50051"
		}
		var err error
		listener, err = net.Listen("tcp", addr)
		if err != nil {
			log.Fatalf("Failed to listen on TCP %s: %v", addr, err)
		}
		log.Printf("🎯 Accounting Core listening on TCP: %s", addr)
	} else {
		// Clean up socket file
		_ = os.Remove(udsPath)
		var err error
		listener, err = net.Listen("unix", udsPath)
		if err != nil {
			log.Fatalf("Failed to listen on UDS socket: %v", err)
		}
		_ = os.Chmod(udsPath, 0777)
		log.Printf("🎯 Accounting Core listening on UDS socket: %s", udsPath)
	}

	grpcServer := grpc.NewServer(
		grpc.KeepaliveParams(keepalive.ServerParameters{
			Time:    30 * time.Second,
			Timeout: 10 * time.Second,
		}),
	)
	pb.RegisterAccountingServiceServer(grpcServer, service)

	// Graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigChan
		log.Println("🛑 Shutting down Accounting Core gRPC server...")
		grpcServer.GracefulStop()
	}()

	if err := grpcServer.Serve(listener); err != nil {
		log.Fatalf("Failed to serve gRPC: %v", err)
	}
	log.Println("Accounting Core service closed.")
}

func appendSimpleProtocol(connURL string) string {
	importQueryMode := "default_query_exec_mode=simple_protocol"
	var delimiter string
	if !strings.Contains(connURL, "default_query_exec_mode=") {
		if strings.Contains(connURL, "?") {
			delimiter = "&"
		} else {
			delimiter = "?"
		}
		connURL = connURL + delimiter + importQueryMode
	}
	if !strings.Contains(connURL, "sslmode=") && !strings.Contains(connURL, "localhost") && !strings.Contains(connURL, "127.0.0.1") {
		connURL = connURL + "&sslmode=require"
	}
	return connURL
}
