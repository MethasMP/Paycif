package main

import (
	"context"
	"crypto/ed25519"
	"database/sql"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	pb "paysif/internal/adapter/grpc/pb"

	"github.com/bytedance/sonic"
	"github.com/google/uuid"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/joho/godotenv"
	"github.com/redis/go-redis/v9"
	"github.com/shopspring/decimal"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/keepalive"
	"google.golang.org/grpc/status"
)

const (
	MaxDailyLimit       = 20000.0 // ฿20,000
	MaxTransactionLimit = 5000.0  // ฿5,000
	MinTransactionLimit = 500.0   // ฿500
)

// CachedRate is a memory-level rate storage
type CachedRate struct {
	Rate        decimal.Decimal
	LastUpdated int64
	ExpiresAt   int64
	Source      string
}

func (c CachedRate) IsExpired() bool {
	return time.Now().Unix() > c.ExpiresAt
}

// UserLimitEntry is pointer-free to avoid Go GC scanning overhead
type UserLimitEntry struct {
	DailyTotal int64 // represented in minor units (satang/cents) to avoid pointers
	Date       int32 // YYYYMMDD representation (e.g. 20260602)
	LastSynced int64 // Unix nanosecond timestamp
	Hydrated   bool
}

func (e UserLimitEntry) IsStale(maxAge time.Duration) bool {
	return time.Since(time.Unix(0, e.LastSynced)) > maxAge
}

func (e UserLimitEntry) IsDifferentDay(today int32) bool {
	return e.Date != today
}

func getTodayInt() int32 {
	t := time.Now().UTC()
	return int32(t.Year()*10000 + int(t.Month())*100 + t.Day())
}

// ILimitCache defines the interface for limit caching in the FX Engine
type ILimitCache interface {
	GetDailyUsage(ctx context.Context, userID uuid.UUID) (int64, error)
	CheckAndReserveLimit(ctx context.Context, userID uuid.UUID, amount int64) (bool, int64, error)
	RevertLimit(userID uuid.UUID, amount int64)
	ApplyRemoteIncrement(userID uuid.UUID, amount int64)
	PreHydrateRecentUsers(ctx context.Context) error
}

// ShardedLimitCache stores UserLimitEntry with 32 shards to avoid global lock contention
type ShardedLimitCache struct {
	shards [32]*LimitShard
	db     *sql.DB
	maxAge time.Duration
}

type LimitShard struct {
	mu   sync.RWMutex
	data map[uuid.UUID]UserLimitEntry
}

func NewShardedLimitCache(db *sql.DB, maxAge time.Duration) *ShardedLimitCache {
	c := &ShardedLimitCache{
		db:     db,
		maxAge: maxAge,
	}
	for i := 0; i < 32; i++ {
		c.shards[i] = &LimitShard{
			data: make(map[uuid.UUID]UserLimitEntry),
		}
	}
	return c
}

func (c *ShardedLimitCache) getShard(u uuid.UUID) *LimitShard {
	// Simple XOR hash of UUID bytes
	var hash byte
	for i := 0; i < 16; i++ {
		hash ^= u[i]
	}
	return c.shards[int(hash)%32]
}

func (c *ShardedLimitCache) GetDailyUsage(ctx context.Context, userID uuid.UUID) (int64, error) {
	shard := c.getShard(userID)
	today := getTodayInt()

	shard.mu.RLock()
	entry, exists := shard.data[userID]
	shard.mu.RUnlock()

	if exists && !entry.IsDifferentDay(today) && !entry.IsStale(c.maxAge) {
		return entry.DailyTotal, nil
	}

	// Cache miss or stale -> Hydrate from DB
	usage, err := c.hydrateFromDB(ctx, userID)
	if err != nil {
		return 0, err
	}

	shard.mu.Lock()
	shard.data[userID] = UserLimitEntry{
		DailyTotal: usage,
		Date:       today,
		LastSynced: time.Now().UnixNano(),
		Hydrated:   true,
	}
	shard.mu.Unlock()

	return usage, nil
}

func (c *ShardedLimitCache) CheckAndReserveLimit(ctx context.Context, userID uuid.UUID, amount int64) (bool, int64, error) {
	today := getTodayInt()
	shard := c.getShard(userID)
	maxDailySatang := int64(MaxDailyLimit * 100)

	// 1. Try fast-path under read lock
	shard.mu.RLock()
	entry, exists := shard.data[userID]
	if exists && !entry.IsDifferentDay(today) && !entry.IsStale(c.maxAge) {
		if entry.DailyTotal+amount > maxDailySatang {
			remaining := maxDailySatang - entry.DailyTotal
			if remaining < 0 {
				remaining = 0
			}
			shard.mu.RUnlock()
			return false, remaining, nil
		}
		shard.mu.RUnlock()

		// Write lock for atomic reservation
		shard.mu.Lock()
		entry = shard.data[userID]
		// Double check under write lock to prevent TOCTOU
		if !entry.IsDifferentDay(today) && !entry.IsStale(c.maxAge) {
			if entry.DailyTotal+amount > maxDailySatang {
				remaining := maxDailySatang - entry.DailyTotal
				if remaining < 0 {
					remaining = 0
				}
				shard.mu.Unlock()
				return false, remaining, nil
			}
			entry.DailyTotal += amount
			entry.LastSynced = time.Now().UnixNano()
			shard.data[userID] = entry
			remaining := maxDailySatang - entry.DailyTotal
			if remaining < 0 {
				remaining = 0
			}
			shard.mu.Unlock()
			return true, remaining, nil
		}
		shard.mu.Unlock()
	} else {
		shard.mu.RUnlock()
	}

	// 2. Slow-path: Hydrate from DB
	usage, err := c.hydrateFromDB(ctx, userID)
	if err != nil {
		return false, 0, err
	}

	// Acquire write lock to update and check/reserve atomically
	shard.mu.Lock()
	defer shard.mu.Unlock()

	currEntry, currExists := shard.data[userID]
	if currExists && !currEntry.IsDifferentDay(today) && !currEntry.IsStale(c.maxAge) {
		entry = currEntry
	} else {
		entry = UserLimitEntry{
			DailyTotal: usage,
			Date:       today,
			LastSynced: time.Now().UnixNano(),
			Hydrated:   true,
		}
		shard.data[userID] = entry
	}

	if entry.DailyTotal+amount > maxDailySatang {
		remaining := maxDailySatang - entry.DailyTotal
		if remaining < 0 {
			remaining = 0
		}
		return false, remaining, nil
	}

	entry.DailyTotal += amount
	entry.LastSynced = time.Now().UnixNano()
	shard.data[userID] = entry

	remaining := maxDailySatang - entry.DailyTotal
	if remaining < 0 {
		remaining = 0
	}
	return true, remaining, nil
}

func (c *ShardedLimitCache) RevertLimit(userID uuid.UUID, amount int64) {
	shard := c.getShard(userID)
	shard.mu.Lock()
	if entry, exists := shard.data[userID]; exists {
		entry.DailyTotal -= amount
		if entry.DailyTotal < 0 {
			entry.DailyTotal = 0
		}
		shard.data[userID] = entry
	}
	shard.mu.Unlock()
}

func (c *ShardedLimitCache) ApplyRemoteIncrement(userID uuid.UUID, amount int64) {
	shard := c.getShard(userID)
	today := getTodayInt()

	shard.mu.Lock()
	entry, exists := shard.data[userID]
	if !exists || entry.IsDifferentDay(today) {
		entry = UserLimitEntry{
			DailyTotal: 0,
			Date:       today,
			LastSynced: time.Now().UnixNano(),
			Hydrated:   false,
		}
	}
	entry.DailyTotal += amount
	entry.LastSynced = time.Now().UnixNano()
	shard.data[userID] = entry
	shard.mu.Unlock()
}

func (c *ShardedLimitCache) hydrateFromDB(ctx context.Context, userID uuid.UUID) (int64, error) {
	if c.db == nil {
		return 0, nil
	}

	var total sql.NullInt64
	// Query ledger entries for debits (amount < 0) for wallets belonging to user today
	query := `
		SELECT SUM(ABS(amount))
		FROM ledger_entries
		WHERE wallet_id IN (SELECT id FROM wallets WHERE profile_id = $1::uuid)
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

func (c *ShardedLimitCache) PreHydrateRecentUsers(ctx context.Context) error {
	if c.db == nil {
		return errors.New("DB not connected")
	}

	query := `
		SELECT w.profile_id, SUM(ABS(le.amount)) 
		FROM ledger_entries le
		JOIN wallets w ON le.wallet_id = w.id
		WHERE le.created_at >= CURRENT_DATE
		GROUP BY w.profile_id
		ORDER BY COUNT(*) DESC
		LIMIT 1000
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
		shard.data[profileID] = UserLimitEntry{
			DailyTotal: total,
			Date:       today,
			LastSynced: time.Now().UnixNano(),
			Hydrated:   true,
		}
		shard.mu.Unlock()
		count++
	}

	log.Printf("🧠 Pre-hydrated %d active users into Go RAM", count)
	return nil
}

// FXEngineServer implements pb.FXServiceServer
type FXEngineServer struct {
	pb.UnimplementedFXServiceServer
	rates      sync.Map
	limitCache ILimitCache
	rdb        *redis.Client
	defaultTTL int64
	startTime  time.Time
}

func NewFXEngineServer(db *sql.DB, rdb *redis.Client, defaultTTL int64) *FXEngineServer {
	limitCache := NewShardedLimitCache(db, 5*time.Minute)
	s := &FXEngineServer{
		limitCache: limitCache,
		rdb:        rdb,
		defaultTTL: defaultTTL,
		startTime:  time.Now(),
	}

	// Insert default USD:THB rate
	s.rates.Store("USD:THB", CachedRate{
		Rate:        decimal.NewFromFloat(35.50),
		LastUpdated: time.Now().Unix(),
		ExpiresAt:   time.Now().Unix() + defaultTTL,
		Source:      "default",
	})

	return s
}

func (s *FXEngineServer) findRate(from, to string) (decimal.Decimal, string, int64, bool) {
	from = strings.ToUpper(from)
	to = strings.ToUpper(to)

	if from == to {
		return decimal.NewFromInt(1), "identity", time.Now().Unix(), true
	}

	// 1. Try Direct
	key := from + ":" + to
	if val, ok := s.rates.Load(key); ok {
		entry := val.(CachedRate)
		if !entry.IsExpired() {
			return entry.Rate, entry.Source, entry.LastUpdated, true
		}
	}

	// 2. Try Inverse
	invKey := to + ":" + from
	if val, ok := s.rates.Load(invKey); ok {
		entry := val.(CachedRate)
		if !entry.IsExpired() && !entry.Rate.IsZero() {
			return decimal.NewFromInt(1).Div(entry.Rate), entry.Source + "-inverted", entry.LastUpdated, true
		}
	}

	// 3. Try Triangular Cross-rate (USD or EUR pivot)
	pivots := []string{"USD", "EUR"}
	for _, pivot := range pivots {
		if from == pivot || to == pivot {
			continue
		}

		r1, src1, ts1, ok1 := s.getDirectOrInverse(from, pivot)
		r2, src2, ts2, ok2 := s.getDirectOrInverse(pivot, to)
		if ok1 && ok2 {
			ts := ts1
			if ts2 < ts {
				ts = ts2
			}
			return r1.Mul(r2), fmt.Sprintf("%s+%s-cross", src1, src2), ts, true
		}
	}

	return decimal.Zero, "", 0, false
}

func (s *FXEngineServer) getDirectOrInverse(from, to string) (decimal.Decimal, string, int64, bool) {
	key := from + ":" + to
	if val, ok := s.rates.Load(key); ok {
		entry := val.(CachedRate)
		if !entry.IsExpired() {
			return entry.Rate, entry.Source, entry.LastUpdated, true
		}
	}
	invKey := to + ":" + from
	if val, ok := s.rates.Load(invKey); ok {
		entry := val.(CachedRate)
		if !entry.IsExpired() && !entry.Rate.IsZero() {
			return decimal.NewFromInt(1).Div(entry.Rate), entry.Source + "-inverted", entry.LastUpdated, true
		}
	}
	return decimal.Zero, "", 0, false
}

// GRPC Convert
func (s *FXEngineServer) Convert(ctx context.Context, in *pb.ConvertRequest) (*pb.ConvertResponse, error) {
	amountDec := decimal.NewFromInt(in.Amount)

	rate, _, ts, ok := s.findRate(in.FromCurrency, in.ToCurrency)
	if !ok {
		return &pb.ConvertResponse{
			Success:      false,
			ErrorMessage: "Pair not found",
		}, nil
	}

	converted := amountDec.Mul(rate).Round(0).IntPart()

	return &pb.ConvertResponse{
		Success:         true,
		ConvertedAmount: converted,
		RateUsed:        rate.String(),
		Timestamp:       ts,
	}, nil
}

// GRPC GetRate
func (s *FXEngineServer) GetRate(ctx context.Context, in *pb.RateRequest) (*pb.RateResponse, error) {
	rate, source, ts, ok := s.findRate(in.FromCurrency, in.ToCurrency)
	if !ok {
		return &pb.RateResponse{
			Success:      false,
			ErrorMessage: "Rate not found (even with cross-rate lookup)",
		}, nil
	}

	invRate := decimal.NewFromInt(1).Div(rate)

	return &pb.RateResponse{
		Success:     true,
		Rate:        rate.String(),
		InverseRate: invRate.String(),
		LastUpdated: ts,
		Source:      source,
	}, nil
}

// GRPC GetAllRates
func (s *FXEngineServer) GetAllRates(ctx context.Context, in *pb.AllRatesRequest) (*pb.AllRatesResponse, error) {
	base := strings.ToUpper(in.BaseCurrency)
	prefix := base + ":"

	ratesMap := make(map[string]string)
	s.rates.Range(func(key, val interface{}) bool {
		k := key.(string)
		entry := val.(CachedRate)
		if strings.HasPrefix(k, prefix) && !entry.IsExpired() {
			target := strings.TrimPrefix(k, prefix)
			ratesMap[target] = entry.Rate.String()
		}
		return true
	})

	return &pb.AllRatesResponse{
		Success:      true,
		BaseCurrency: base,
		Rates:        ratesMap,
		LastUpdated:  time.Now().Unix(),
	}, nil
}

// GRPC HealthCheck
func (s *FXEngineServer) HealthCheck(ctx context.Context, in *pb.FXHealthRequest) (*pb.FXHealthResponse, error) {
	count := int32(0)
	s.rates.Range(func(k, v interface{}) bool {
		count++
		return true
	})

	return &pb.FXHealthResponse{
		Healthy:       true,
		Version:       "3.0-go-uds",
		CachedPairs:   count,
		UptimeSeconds: int64(time.Since(s.startTime).Seconds()),
	}, nil
}

// GRPC UpdateRate (Administrative/Control Plane)
func (s *FXEngineServer) UpdateRate(ctx context.Context, in *pb.UpdateRateRequest) (*pb.UpdateRateResponse, error) {
	rateDec, err := decimal.NewFromString(in.Rate)
	if err != nil || rateDec.LessThanOrEqual(decimal.Zero) {
		return nil, status.Errorf(codes.InvalidArgument, "Invalid rate format/must be positive")
	}

	key := strings.ToUpper(in.FromCurrency) + ":" + strings.ToUpper(in.ToCurrency)
	s.rates.Store(key, CachedRate{
		Rate:        rateDec,
		LastUpdated: time.Now().Unix(),
		ExpiresAt:   time.Now().Unix() + s.defaultTTL,
		Source:      in.Source,
	})

	log.Printf("Rate updated: %s -> %s = %s", in.FromCurrency, in.ToCurrency, in.Rate)

	return &pb.UpdateRateResponse{
		Success: true,
		Message: "Rate updated via sync.Map",
	}, nil
}

// GRPC VerifySignature
func (s *FXEngineServer) VerifySignature(ctx context.Context, in *pb.VerifySignatureRequest) (*pb.VerifySignatureResponse, error) {
	if len(in.PublicKey) != 32 {
		return &pb.VerifySignatureResponse{
			Valid:        false,
			ErrorMessage: "Invalid Public Key length (must be 32 bytes)",
		}, nil
	}
	if len(in.Signature) != 64 {
		return &pb.VerifySignatureResponse{
			Valid:        false,
			ErrorMessage: "Invalid Signature length (must be 64 bytes)",
		}, nil
	}

	valid := ed25519.Verify(in.PublicKey, in.Message, in.Signature)
	if !valid {
		return &pb.VerifySignatureResponse{
			Valid:        false,
			ErrorMessage: "Signature verification failed",
		}, nil
	}

	return &pb.VerifySignatureResponse{
		Valid: true,
	}, nil
}

// GRPC GetLimits
func (s *FXEngineServer) GetLimits(ctx context.Context, in *pb.GetLimitsRequest) (*pb.GetLimitsResponse, error) {
	uid, err := uuid.Parse(in.UserId)
	if err != nil {
		return &pb.GetLimitsResponse{
			Success:      false,
			ErrorMessage: "Invalid UUID format",
		}, nil
	}

	usage, err := s.limitCache.GetDailyUsage(ctx, uid)
	if err != nil {
		return &pb.GetLimitsResponse{
			Success:      false,
			ErrorMessage: err.Error(),
		}, nil
	}

	usageF64 := float64(usage) / 100.0
	remaining := MaxDailyLimit - usageF64
	if remaining < 0 {
		remaining = 0
	}

	return &pb.GetLimitsResponse{
		Success:              true,
		MaxDailyAmount:       MaxDailyLimit,
		RemainingDailyAmount: remaining,
		CurrentDailyTotal:    usageF64,
		MaxTransactionAmount: MaxTransactionLimit,
	}, nil
}

// GRPC PreValidateTransfer
func (s *FXEngineServer) PreValidateTransfer(ctx context.Context, in *pb.PreValidateTransferRequest) (*pb.PreValidateTransferResponse, error) {
	if in.Amount <= 0 {
		return &pb.PreValidateTransferResponse{
			Valid:        false,
			ErrorMessage: "Amount must be positive",
		}, nil
	}

	amountMajor := float64(in.Amount) / 100.0

	if amountMajor > MaxTransactionLimit {
		return &pb.PreValidateTransferResponse{
			Valid:        false,
			ErrorMessage: fmt.Sprintf("Amount exceeds transaction limit of %.2f", MaxTransactionLimit),
		}, nil
	}
	if amountMajor < MinTransactionLimit {
		return &pb.PreValidateTransferResponse{
			Valid:        false,
			ErrorMessage: fmt.Sprintf("Amount is below minimum requirement of %.2f", MinTransactionLimit),
		}, nil
	}

	// Verify cryptographic signature
	if len(in.PublicKey) != 32 || len(in.Signature) != 64 {
		return &pb.PreValidateTransferResponse{
			Valid:        false,
			ErrorMessage: "Invalid key/signature length",
		}, nil
	}
	if !ed25519.Verify(in.PublicKey, in.Message, in.Signature) {
		return &pb.PreValidateTransferResponse{
			Valid:        false,
			ErrorMessage: "Signature verification failed",
		}, nil
	}

	uid, err := uuid.Parse(in.UserId)
	if err != nil {
		return &pb.PreValidateTransferResponse{
			Valid:        false,
			ErrorMessage: "Invalid user UUID format",
		}, nil
	}

	// Limit check and optimistic reservation atomically
	allowed, remaining, err := s.limitCache.CheckAndReserveLimit(ctx, uid, in.Amount)
	if err != nil {
		return &pb.PreValidateTransferResponse{
			Valid:        false,
			ErrorMessage: "Failed to fetch limit: " + err.Error(),
		}, nil
	}

	if !allowed {
		return &pb.PreValidateTransferResponse{
			Valid:                false,
			SignatureValid:       true,
			LimitsValid:          false,
			ErrorMessage:         fmt.Sprintf("Daily limit exceeded. Remaining: %.2f", float64(remaining)/100.0),
			RemainingDailyAmount: float64(remaining) / 100.0,
		}, nil
	}

	return &pb.PreValidateTransferResponse{
		Valid:                true,
		SignatureValid:       true,
		LimitsValid:          true,
		RemainingDailyAmount: float64(remaining) / 100.0,
	}, nil
}

// ExchangeRate represents a rate from provider
type ExchangeRate struct {
	From   string
	To     string
	Rate   decimal.Decimal
	Source string
}

// ECB Provider XML structures
type Envelope struct {
	XMLName xml.Name `xml:"Envelope"`
	Cube    Cube     `xml:"Cube"`
}

type Cube struct {
	Cube []TimeCube `xml:"Cube"`
}

type TimeCube struct {
	Time string     `xml:"time,attr"`
	Cube []RateCube `xml:"Cube"`
}

type RateCube struct {
	Currency string `xml:"currency,attr"`
	Rate     string `xml:"rate,attr"`
}

// Fetch ECB XML Rates
func fetchECBRates(ctx context.Context) ([]ExchangeRate, error) {
	client := &http.Client{Timeout: 10 * time.Second}
	req, err := http.NewRequestWithContext(ctx, "GET", "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml", nil)
	if err != nil {
		return nil, err
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("ECB API returned status: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var envelope Envelope
	if err := xml.Unmarshal(body, &envelope); err != nil {
		return nil, err
	}

	var results []ExchangeRate
	if len(envelope.Cube.Cube) > 0 {
		for _, rc := range envelope.Cube.Cube[0].Cube {
			rateDec, err := decimal.NewFromString(rc.Rate)
			if err == nil {
				results = append(results, ExchangeRate{
					From:   "EUR",
					To:     rc.Currency,
					Rate:   rateDec,
					Source: "ECB",
				})
			}
		}
	}
	return results, nil
}

// OpenExchangeRates structures
type OXRResponse struct {
	Rates map[string]float64 `json:"rates"`
}

func fetchOXR(ctx context.Context, apiKey, base string) ([]ExchangeRate, error) {
	client := &http.Client{Timeout: 10 * time.Second}
	url := fmt.Sprintf("https://openexchangerates.org/api/latest.json?app_id=%s&base=%s", apiKey, base)
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("OXR API returned status: %d", resp.StatusCode)
	}

	var data OXRResponse
	if err := sonic.ConfigDefault.NewDecoder(resp.Body).Decode(&data); err != nil {
		return nil, err
	}

	var results []ExchangeRate
	for curr, val := range data.Rates {
		results = append(results, ExchangeRate{
			From:   base,
			To:     curr,
			Rate:   decimal.NewFromFloat(val),
			Source: "OpenExchangeRates",
		})
	}
	return results, nil
}

func main() {
	_ = godotenv.Load()

	log.Println("🚀 Go FX Engine microservice starting...")

	// Database Connection (Optional fallback)
	dbURL := os.Getenv("DATABASE_URL")
	var db *sql.DB
	var err error
	if dbURL != "" {
		dbURL = appendSimpleProtocol(dbURL)
		db, err = sql.Open("pgx", dbURL)
		if err != nil {
			log.Printf("⚠️ Database connection failed: %v. Operates in memory-only.", err)
			db = nil
		} else {
			db.SetMaxOpenConns(5)
			if err := db.Ping(); err != nil {
				log.Printf("⚠️ Database ping failed: %v. Operates in memory-only.", err)
				db = nil
			} else {
				log.Println("✅ Connected to Postgres database")
			}
		}
	}

	// Redis connection
	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		redisURL = "redis://127.0.0.1:6379/0"
	}
	opt, err := redis.ParseURL(redisURL)
	var rdb *redis.Client
	if err != nil {
		log.Printf("⚠️ Redis parsing failed: %v. Running without Redis caching.", err)
	} else {
		rdb = redis.NewClient(opt)
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		if err := rdb.Ping(ctx).Err(); err != nil {
			log.Printf("⚠️ Redis ping failed: %v. Running without Redis caching.", err)
			rdb = nil
		} else {
			log.Println("✅ Connected to Redis cache")
		}
		cancel()
	}

	defaultTTL := int64(3600)
	if ttlStr := os.Getenv("RATE_TTL_SECONDS"); ttlStr != "" {
		if val, err := strconv.ParseInt(ttlStr, 10, 64); err == nil {
			defaultTTL = val
		}
	}

	srv := NewFXEngineServer(db, rdb, defaultTTL)

	// Pre-hydrate recent user limits
	if db != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		_ = srv.limitCache.PreHydrateRecentUsers(ctx)
		cancel()
	}

	// Background: Hydrate limits periodically
	if db != nil {
		go func() {
			for {
				time.Sleep(5 * time.Minute)
				ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
				if err := srv.limitCache.PreHydrateRecentUsers(ctx); err != nil {
					log.Printf("❌ Periodic limit hydration failed: %v", err)
				}
				cancel()
			}
		}()
	}

	// Background: Redis Pub/Sub syncing user limits
	if rdb != nil {
		go func() {
			pubsub := rdb.Subscribe(context.Background(), "user_limit_updates")
			defer pubsub.Close()

			log.Println("📡 Subscribed to Redis channel 'user_limit_updates'")
			ch := pubsub.Channel()

			for msg := range ch {
				// Format: user_id:amount
				parts := strings.Split(msg.Payload, ":")
				if len(parts) == 2 {
					uid, err := uuid.Parse(parts[0])
					if err == nil {
						amount, err := strconv.ParseInt(parts[1], 10, 64)
						if err == nil {
							srv.limitCache.ApplyRemoteIncrement(uid, amount)
						}
					}
				}
			}
		}()
	}

	// Background: Periodically fetch rates from providers
	go func() {
		for {
			ctx := context.Background()
			// 1. ECB
			ecbRates, err := fetchECBRates(ctx)
			if err == nil {
				for _, r := range ecbRates {
					srv.rates.Store(r.From+":"+r.To, CachedRate{
						Rate:        r.Rate,
						LastUpdated: time.Now().Unix(),
						ExpiresAt:   time.Now().Unix() + defaultTTL,
						Source:      r.Source,
					})
				}
				log.Printf("🔄 Fetched rates from ECB provider")
			} else {
				log.Printf("⚠️ ECB Provider fetch error: %v", err)
			}

			// 2. Mock
			mockPairs := []string{"EUR:USD", "EUR:GBP", "EUR:THB"}
			mockRates := []float64{1.0850, 0.8500, 38.50}
			for i, pair := range mockPairs {
				srv.rates.Store(pair, CachedRate{
					Rate:        decimal.NewFromFloat(mockRates[i]),
					LastUpdated: time.Now().Unix(),
					ExpiresAt:   time.Now().Unix() + defaultTTL,
					Source:      "Mock",
				})
			}

			// Save rates to Redis if present
			if rdb != nil {
				pipe := rdb.Pipeline()
				srv.rates.Range(func(key, val interface{}) bool {
					k := key.(string)
					entry := val.(CachedRate)
					rKey := "fx:rate:" + k
					rVal := fmt.Sprintf("%s:%s", entry.Rate.String(), entry.Source)
					pipe.SetEx(ctx, rKey, rVal, time.Duration(defaultTTL)*time.Second)
					return true
				})
				_, _ = pipe.Exec(ctx)
			}

			time.Sleep(30 * time.Minute)
		}
	}()

	// Background: Cleanup expired rates
	go func() {
		for {
			time.Sleep(5 * time.Minute)
			now := time.Now().Unix()
			expired := 0
			srv.rates.Range(func(key, val interface{}) bool {
				entry := val.(CachedRate)
				if now > entry.ExpiresAt {
					srv.rates.Delete(key)
					expired++
				}
				return true
			})
			if expired > 0 {
				log.Printf("🧹 Cleaned up %d expired rates from Go memory", expired)
			}
		}
	}()

	// Listeners
	var listener net.Listener
	udsPath := os.Getenv("FX_ENGINE_UDS")

	// UDS by default to match recommended config, fallback to TCP
	if udsPath == "" {
		udsPath = "/tmp/fx_engine.sock" // Default UDS
	}

	if os.Getenv("FX_ENGINE_TCP_ONLY") == "true" {
		addr := os.Getenv("FX_ENGINE_ADDR")
		if addr == "" {
			addr = "0.0.0.0:50052"
		}
		listener, err = net.Listen("tcp", addr)
		if err != nil {
			log.Fatalf("Failed to listen on TCP: %v", err)
		}
		log.Printf("🌐 Go FX Engine listening on TCP: %s", addr)
	} else {
		// Clean up socket file
		_ = os.Remove(udsPath)
		listener, err = net.Listen("unix", udsPath)
		if err != nil {
			log.Fatalf("Failed to listen on UDS socket: %v", err)
		}
		_ = os.Chmod(udsPath, 0777)
		log.Printf("⚡ Go FX Engine listening on UDS socket: %s", udsPath)
	}

	grpcServer := grpc.NewServer(
		grpc.KeepaliveParams(keepalive.ServerParameters{
			Time:    30 * time.Second,
			Timeout: 10 * time.Second,
		}),
	)
	pb.RegisterFXServiceServer(grpcServer, srv)

	// Graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigChan
		log.Println("🛑 Shutting down FX gRPC server...")
		grpcServer.GracefulStop()
		if _, err := os.Stat(udsPath); err == nil {
			_ = os.Remove(udsPath)
		}
	}()

	if err := grpcServer.Serve(listener); err != nil {
		log.Fatalf("Failed to serve gRPC: %v", err)
	}
	log.Println("FX Engine service closed.")
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
