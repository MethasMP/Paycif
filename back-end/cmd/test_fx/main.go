package main

import (
	"context"
	"fmt"
	"time"

	fxrpc "paysif/internal/grpc"
)

func main() {
	fmt.Println("💱 FX Engine Integration Test")
	fmt.Println("==============================")

	// Connect to FX Engine
	fmt.Println("\n[1] Connecting to Rust FX Engine...")
	client, err := fxrpc.NewFXClient("[::1]:50052")
	if err != nil {
		fmt.Printf("❌ Connection failed: %v\n", err)
		fmt.Println("\n⚠️  Make sure FX Engine is running:")
		fmt.Println("   ./back-end/start-rust-services.sh")
		return
	}
	defer client.Close()
	fmt.Println("✅ Connected!")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Health Check
	fmt.Println("\n[2] Health Check...")
	health, err := client.HealthCheck(ctx)
	if err != nil {
		fmt.Printf("❌ Health check failed: %v\n", err)
		return
	}
	fmt.Printf("✅ Healthy: %v, Version: %s, Cached Pairs: %d\n",
		health.Healthy, health.Version, health.CachedPairs)

	// Get Rate
	fmt.Println("\n[3] Get Exchange Rate (USD -> THB)...")
	rate, err := client.GetRate(ctx, "USD", "THB", "test-1")
	if err != nil {
		fmt.Printf("❌ Get rate failed: %v\n", err)
	} else {
		fmt.Printf("✅ Rate: %s, Last Updated: %d\n", rate.Rate, rate.LastUpdated)
	}

	// Convert
	fmt.Println("\n[4] Convert 100 USD to THB...")
	// Amount in smallest unit (cents): 100 USD = 10000 cents
	conv, err := client.Convert(ctx, "USD", "THB", 10000, "test-2")
	if err != nil {
		fmt.Printf("❌ Convert failed: %v\n", err)
	} else {
		fmt.Printf("✅ Converted: %d satang (= %.2f THB), Rate Used: %s\n",
			conv.ConvertedAmount, float64(conv.ConvertedAmount)/100, conv.RateUsed)
	}

	// Get All Rates for THB
	fmt.Println("\n[5] Get All Rates for THB...")
	allRates, err := client.GetAllRates(ctx, "THB", "test-3")
	if err != nil {
		fmt.Printf("❌ Get all rates failed: %v\n", err)
	} else {
		fmt.Printf("✅ Found %d rates for THB:\n", len(allRates.Rates))
		for curr, rate := range allRates.Rates {
			fmt.Printf("   THB -> %s: %s\n", curr, rate)
		}
	}

	// Benchmark
	fmt.Println("\n[6] Benchmark: 1000 Convert requests...")
	start := time.Now()
	for i := 0; i < 1000; i++ {
		_, err := client.Convert(ctx, "USD", "THB", 10000, fmt.Sprintf("bench-%d", i))
		if err != nil {
			fmt.Printf("❌ Request %d failed: %v\n", i, err)
			break
		}
	}
	elapsed := time.Since(start)
	fmt.Printf("✅ 1000 requests in %v\n", elapsed)
	fmt.Printf("   Avg Latency: %.2f ms\n", float64(elapsed.Microseconds())/1000)
	fmt.Printf("   Throughput: %.0f req/s\n", 1000/elapsed.Seconds())

	fmt.Println("\n==============================")
	fmt.Println("🎉 FX Engine Test Complete!")
}
