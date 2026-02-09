package main

import (
	"context"
	"fmt"
	"time"

	grpcclient "paysif/internal/grpc"
)

func main() {
	fmt.Println("🔐 Accounting Client mTLS Integration Test")
	fmt.Println("========================================")

	// Configure TLS
	cfg := grpcclient.DefaultClientConfig("[::1]:50051")
	cfg.EnableTLS = true
	cfg.CACertPath = "back-end/certs/ca-cert.pem"
	cfg.ClientCertPath = "back-end/certs/client-cert.pem"
	cfg.ClientKeyPath = "back-end/certs/client-key.pem"
	cfg.EnableHealthChecks = true

	fmt.Println("\n[1] Testing SECURE connection to Rust Accounting Core...")

	client, err := grpcclient.NewAccountingClientWithConfig(cfg)
	if err != nil {
		fmt.Printf("❌ Secure Connection failed: %v\n", err)
		fmt.Println("\n⚠️  Make sure Rust service is running with ENABLE_TLS=true")
		return
	}
	defer client.Close()

	fmt.Printf("✅ Connected Securely to: %s\n", client.GetAddress())

	// Health Check
	fmt.Println("\n[2] Running Health Check over mTLS...")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	healthResp, err := client.HealthCheck(ctx)
	if err != nil {
		fmt.Printf("❌ Health check failed: %v\n", err)
		return
	}
	fmt.Printf("✅ Service Healthy: %v (Version: %s)\n", healthResp.Healthy, healthResp.Version)

	fmt.Println("\n========================================")
	fmt.Println("🎉 mTLS Handshake & Communication SUCCESS!")
}
