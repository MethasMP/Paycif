package main

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"time"
)

func main() {
	// 1. Generate Key Pair
	pubKey, privKey, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		panic(err)
	}

	msg := "Paycif High Performance Test"
	sig := ed25519.Sign(privKey, []byte(msg))

	pubB64 := base64.StdEncoding.EncodeToString(pubKey)
	sigB64 := base64.StdEncoding.EncodeToString(sig)

	payload := map[string]string{
		"public_key_b64": pubB64,
		"signature_b64":  sigB64,
		"message":        msg,
	}
	jsonBytes, _ := json.Marshal(payload)

	fmt.Println("🔥 Starting Rust Verify Service Benchmark (1,000 requests)...")

	var client *http.Client
	url := "http://localhost/verify"

	if os.Getenv("VERIFY_SERVICE_TCP_ONLY") == "true" {
		client = &http.Client{Timeout: 1 * time.Second}
		port := os.Getenv("VERIFY_SERVICE_PORT")
		if port == "" {
			port = "3001"
		}
		url = "http://localhost:" + port + "/verify"
	} else {
		udsPath := os.Getenv("VERIFY_SERVICE_UDS")
		if udsPath == "" {
			udsPath = "/tmp/verify_service.sock"
		}
		client = &http.Client{
			Timeout: 1 * time.Second,
			Transport: &http.Transport{
				DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
					return net.Dial("unix", udsPath)
				},
			},
		}
	}

	start := time.Now()
	success := 0
	iterations := 1000

	for i := 0; i < iterations; i++ {
		resp, err := client.Post(url, "application/json", bytes.NewBuffer(jsonBytes))
		if err != nil {
			fmt.Printf("Request failed: %v\n", err)
			continue
		}
		resp.Body.Close()
		if resp.StatusCode == 200 {
			success++
		}
	}

	elapsed := time.Since(start)
	avg := elapsed / time.Duration(iterations)

	fmt.Printf("\n✅ Completed %d/%d requests successfully.\n", success, iterations)
	fmt.Printf("⏱️ Total Time: %s\n", elapsed)
	fmt.Printf("🚀 Average Latency: %s/req\n", avg)
	fmt.Printf("⚡ Throughput: %.2f req/sec\n", float64(iterations)/elapsed.Seconds())
}
