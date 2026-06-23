package main

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/joho/godotenv"
)

// PromptPayPayoutRequest matches the API Gateway request schema
type PromptPayPayoutRequest struct {
	Amount         int64  `json:"amount"`
	PromptPayID    string `json:"promptpay_id"`
	RecipientName  string `json:"recipient_name"`
	IdempotencyKey string `json:"idempotency_key"`
	SqrilTxID      string `json:"sqril_tx_id"`
	BillerID       string `json:"biller_id"`
	Reference1     string `json:"reference1"`
	Reference2     string `json:"reference2"`
}

// ComputePayloadHash replicates the server-side payload hashing logic
func ComputePayloadHash(req PromptPayPayoutRequest) string {
	h := sha256.New()
	h.Write([]byte(strconv.FormatInt(req.Amount, 10)))
	h.Write([]byte{':'})
	h.Write([]byte(req.PromptPayID))
	h.Write([]byte{':'})
	h.Write([]byte(req.RecipientName))
	h.Write([]byte{':'})
	h.Write([]byte(req.IdempotencyKey))
	h.Write([]byte{':'})
	h.Write([]byte(req.SqrilTxID))
	h.Write([]byte{':'})
	h.Write([]byte(req.BillerID))
	h.Write([]byte{':'})
	h.Write([]byte(req.Reference1))
	h.Write([]byte{':'})
	h.Write([]byte(req.Reference2))
	return hex.EncodeToString(h.Sum(nil))
}

type result struct {
	duration   time.Duration
	statusCode int
	err        error
}

func main() {
	// 1. Flags Configuration
	concurrency := flag.Int("concurrency", 10, "Number of concurrent workers")
	totalRequests := flag.Int("requests", 100, "Total requests to make")
	endpoint := flag.String("endpoint", "http://localhost:8080/api/v1/payout/promptpay", "Target payout endpoint URL")
	amount := flag.Int64("amount", 1000, "Payout amount per request in satang (10 THB)")
	flag.Parse()

	_ = godotenv.Load()
	_ = godotenv.Load("../../.env")

	// 2. Database Preparation
	connStr := os.Getenv("DATABASE_URL")
	if connStr == "" {
		fmt.Println("❌ DATABASE_URL is not set")
		os.Exit(1)
	}

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

	fmt.Println("Connecting to DB...")
	db, err := sql.Open("pgx", connStr)
	if err != nil {
		fmt.Printf("❌ Failed to open database: %v\n", err)
		os.Exit(1)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		fmt.Printf("❌ Database ping failed: %v\n", err)
		os.Exit(1)
	}

	// 3. Register Seed User, Devices, & Wallet Balance
	testUserID := uuid.New()
	testDeviceID := "load-test-device-" + uuid.New().String()[:8]

	fmt.Printf("Generating cryptographic signatures & credentials for Load Test User: %s...\n", testUserID)
	pubKey, privKey, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		panic(err)
	}
	pubKeyB64 := base64.StdEncoding.EncodeToString(pubKey)

	// Create profile
	_, err = db.Exec(`
		INSERT INTO profiles (id, username, full_name, kyc_tier, kyc_status, account_status)
		VALUES ($1, $2, 'Load Test User', 'tier2', 'VERIFIED', 'ACTIVE')
		ON CONFLICT (id) DO NOTHING
	`, testUserID, "load_test_"+testUserID.String()[:8])
	if err != nil {
		panic(err)
	}

	// Bind device
	_, err = db.Exec(`
		INSERT INTO user_device_bindings (id, user_id, device_id, public_key, is_active, device_name, os_type)
		VALUES ($1, $2, $3, $4, true, 'Benchmark Worker', 'ios')
	`, uuid.New(), testUserID, testDeviceID, pubKeyB64)
	if err != nil {
		panic(err)
	}

	// Seed Balance (Add 10,000,000 Satang = 100,000 THB)
	initTxID := uuid.New()
	_, err = db.Exec(`
		INSERT INTO transactions (id, profile_id, reference_id, amount, description, settlement_status, type, status)
		VALUES ($1, $2, $3, $4, 'Load Test Funding', 'SETTLED', 'TOPUP', 'SUCCESS')
	`, initTxID, testUserID, "load_test_fund_"+initTxID.String(), 10000000)
	if err != nil {
		panic(err)
	}

	_, err = db.Exec(`
		INSERT INTO ledger_entries (id, transaction_id, profile_id, amount, balance_after, base_currency_amount, home_currency_amount)
		VALUES ($1, $2, $3, $4, $4, $4, $4)
	`, uuid.New(), initTxID, testUserID, 10000000)
	if err != nil {
		panic(err)
	}

	fmt.Println("🚀 Seed Completed. Wallet balance initialized to 100,000.00 THB.")

	// 4. Run Load Test
	fmt.Printf("\n🔥 Starting Load Test: %d Requests, Concurrency=%d, Amount=%d satang\n", *totalRequests, *concurrency, *amount)

	client := &http.Client{
		Timeout: 20 * time.Second,
		Transport: &http.Transport{
			MaxIdleConns:        100,
			MaxIdleConnsPerHost: *concurrency,
		},
	}

	results := make([]result, 0, *totalRequests)
	var mu sync.Mutex

	reqChan := make(chan int, *totalRequests)
	for i := 0; i < *totalRequests; i++ {
		reqChan <- i
	}
	close(reqChan)

	var wg sync.WaitGroup
	startTime := time.Now()

	for w := 0; w < *concurrency; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range reqChan {
				idempKey := uuid.New().String()
				payoutReq := PromptPayPayoutRequest{
					Amount:         *amount,
					PromptPayID:    "1400000053", // Mock CPF Store QR PromptPay ID
					RecipientName:  "CPF Store",
					IdempotencyKey: idempKey,
					SqrilTxID:      "mock_tx_" + idempKey,
					BillerID:       "",
					Reference1:     "LOADTEST",
					Reference2:     "STRESS",
				}

				payloadHash := ComputePayloadHash(payoutReq)
				signatureBytes := ed25519.Sign(privKey, []byte(payloadHash))
				signatureB64 := base64.StdEncoding.EncodeToString(signatureBytes)

				reqJSON, _ := json.Marshal(payoutReq)

				req, err := http.NewRequest("POST", *endpoint, bytes.NewBuffer(reqJSON))
				if err != nil {
					mu.Lock()
					results = append(results, result{err: err})
					mu.Unlock()
					continue
				}

				req.Header.Set("Content-Type", "application/json")
				req.Header.Set("X-Device-Id", testDeviceID)
				req.Header.Set("X-Device-Signature", signatureB64)
				req.Header.Set("X-Load-Test-User-Id", testUserID.String())

				reqStart := time.Now()
				resp, err := client.Do(req)
				reqDuration := time.Since(reqStart)

				if err != nil {
					mu.Lock()
					results = append(results, result{duration: reqDuration, err: err})
					mu.Unlock()
					continue
				}

				_, _ = io.Copy(io.Discard, resp.Body)
				resp.Body.Close()

				mu.Lock()
				results = append(results, result{duration: reqDuration, statusCode: resp.StatusCode})
				mu.Unlock()
			}
		}()
	}

	wg.Wait()
	totalDuration := time.Since(startTime)

	// 5. Build Report
	var successfulCount, failedCount int
	statusCodes := make(map[int]int)
	latencies := make([]time.Duration, 0, len(results))

	for _, res := range results {
		if res.err != nil {
			failedCount++
			continue
		}
		statusCodes[res.statusCode]++
		if res.statusCode == http.StatusOK || res.statusCode == http.StatusAccepted {
			successfulCount++
		} else {
			failedCount++
		}
		latencies = append(latencies, res.duration)
	}

	sort.Slice(latencies, func(i, j int) bool {
		return latencies[i] < latencies[j]
	})

	var sumLatencies int64
	for _, l := range latencies {
		sumLatencies += l.Nanoseconds()
	}

	meanLatency := time.Duration(0)
	p50 := time.Duration(0)
	p90 := time.Duration(0)
	p95 := time.Duration(0)
	p99 := time.Duration(0)

	if len(latencies) > 0 {
		meanLatency = time.Duration(sumLatencies / int64(len(latencies)))
		p50 = latencies[len(latencies)*50/100]
		p90 = latencies[len(latencies)*90/100]
		p95 = latencies[len(latencies)*95/100]
		p99 = latencies[len(latencies)*99/100]
	}

	rps := float64(*totalRequests) / totalDuration.Seconds()

	fmt.Println("\n================ LOAD TEST REPORT ================")
	fmt.Printf("⏱️  Total Test Time    : %s\n", totalDuration)
	fmt.Printf("🚀 Throughput (RPS)    : %.2f req/sec\n", rps)
	fmt.Printf("✅ Success Rate        : %d/%d (%.2f%%)\n", successfulCount, *totalRequests, float64(successfulCount)/float64(*totalRequests)*100)
	fmt.Printf("❌ Failure Rate        : %d/%d (%.2f%%)\n", failedCount, *totalRequests, float64(failedCount)/float64(*totalRequests)*100)

	fmt.Println("\n📊 Latency Metrics:")
	fmt.Printf("   Mean Latency        : %s\n", meanLatency)
	fmt.Printf("   Median (p50)        : %s\n", p50)
	fmt.Printf("   90th Percentile (p90): %s\n", p90)
	fmt.Printf("   95th Percentile (p95): %s\n", p95)
	fmt.Printf("   99th Percentile (p99): %s\n", p99)

	fmt.Println("\n📡 HTTP Status Distribution:")
	for code, count := range statusCodes {
		fmt.Printf("   HTTP %d             : %d\n", code, count)
	}
	fmt.Println("==================================================")
}
