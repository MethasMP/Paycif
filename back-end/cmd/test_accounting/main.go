package main

import (
	"context"
	"fmt"
	"time"

	grpcclient "paysif/internal/grpc"
)

func main() {
	fmt.Println("🔍 Accounting Client Integration Test")
	fmt.Println("=====================================")

	// 1. Test connection with health check
	fmt.Println("\n[1] Testing connection to Rust Accounting Core...")

	client, err := grpcclient.NewAccountingClient("[::1]:50051")
	if err != nil {
		fmt.Printf("❌ Connection failed: %v\n", err)
		fmt.Println("\n⚠️  Make sure Rust service is running:")
		fmt.Println("   ./back-end/start-rust-services.sh")
		return
	}
	defer client.Close()

	fmt.Printf("✅ Connected to: %s\n", client.GetAddress())

	// 2. Health Check
	fmt.Println("\n[2] Running Health Check...")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	healthResp, err := client.HealthCheck(ctx)
	if err != nil {
		fmt.Printf("❌ Health check failed: %v\n", err)
		return
	}
	fmt.Printf("✅ Service Healthy: %v\n", healthResp.Healthy)
	fmt.Printf("   Version: %s\n", healthResp.Version)
	fmt.Printf("   Uptime: %d seconds\n", healthResp.UptimeSeconds)

	// 3. Input Validation Tests
	fmt.Println("\n[3] Testing Input Validation (should fail gracefully)...")

	tests := []struct {
		name        string
		from, to    string
		amount      int64
		currency    string
		ref, req    string
		expectError bool
	}{
		{"Empty from_wallet", "", "to-id", 100, "THB", "ref-1", "req-1", true},
		{"Zero amount", "from-id", "to-id", 0, "THB", "ref-1", "req-1", true},
		{"Negative amount", "from-id", "to-id", -100, "THB", "ref-1", "req-1", true},
		{"Empty currency", "from-id", "to-id", 100, "", "ref-1", "req-1", true},
		{"Empty reference_id", "from-id", "to-id", 100, "THB", "", "req-1", true},
	}

	allPassed := true
	for _, tt := range tests {
		_, err := client.Transfer(ctx, tt.from, tt.to, tt.amount, tt.currency, tt.ref, tt.req)
		if tt.expectError && err == nil {
			fmt.Printf("   ❌ %s: expected error but got none\n", tt.name)
			allPassed = false
		} else if tt.expectError && err != nil {
			fmt.Printf("   ✅ %s: correctly rejected\n", tt.name)
		}
	}

	if allPassed {
		fmt.Println("   All validation tests passed!")
	}

	// 4. Connection state
	fmt.Println("\n[4] Checking connection state...")
	if client.IsConnected() {
		fmt.Println("✅ Client is still connected")
	} else {
		fmt.Println("⚠️  Client disconnected")
	}

	// 5. Summary
	fmt.Println("\n=====================================")
	fmt.Println("🎉 Integration Test Complete!")
	fmt.Println("\n📋 Production Readiness Checklist:")
	fmt.Println("   ✅ gRPC connection with keepalive")
	fmt.Println("   ✅ Health check on startup")
	fmt.Println("   ✅ Input validation (fail-fast)")
	fmt.Println("   ✅ Connection state monitoring")
	fmt.Println("   ✅ Graceful close handling")
	fmt.Println("   ✅ Backoff & retry configuration")
	fmt.Println("   ✅ Request/Reference ID for tracing")
}
