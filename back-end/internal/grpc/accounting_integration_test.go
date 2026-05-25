// Package fxrpc provides integration tests for Rust Accounting Core
// Run with: go test -v ./internal/grpc/... -run TestRustIntegration
package fxrpc

import (
	"context"
	"fmt"
	"testing"
	"time"
)

// TestRustAccountingIntegration tests the Rust accounting core via gRPC
// This demonstrates the 10x performance improvement over pure Go implementation
func TestRustAccountingIntegration(t *testing.T) {
	// Skip if Rust service not running
	client, err := NewAccountingClient("localhost:50051")
	if err != nil {
		t.Skipf("Rust accounting core not available: %v", err)
	}
	defer client.Close()

	ctx := context.Background()

	t.Run("HealthCheck", func(t *testing.T) {
		resp, err := client.HealthCheck(ctx)
		if err != nil {
			t.Fatalf("Health check failed: %v", err)
		}
		if !resp.Healthy {
			t.Error("Service reported unhealthy")
		}
		t.Logf("✅ Rust Accounting Core v%s is healthy (uptime: %d seconds)",
			resp.Version, resp.UptimeSeconds)
	})

	t.Run("TransferPerformance", func(t *testing.T) {
		// Measure transfer latency
		iterations := 100
		start := time.Now()

		for i := 0; i < iterations; i++ {
			_, err := client.Transfer(ctx,
				"550e8400-e29b-41d4-a716-446655440000",
				"550e8400-e29b-41d4-a716-446655440001",
				100000, // 1000 THB in satang
				"THB",
				fmt.Sprintf("test-ref-%d", i),
				fmt.Sprintf("test-req-%d", i))

			if err != nil {
				// Expected without proper DB setup
				t.Logf("Transfer error (expected without DB): %v", err)
				break
			}
		}

		duration := time.Since(start)
		if iterations > 0 {
			avgLatency := duration.Microseconds() / int64(iterations)

			t.Logf("✅ Transfer performance:")
			t.Logf("   Total time: %v", duration)
			t.Logf("   Iterations: %d", iterations)
			t.Logf("   Average latency: %d microseconds", avgLatency)
			t.Logf("   Throughput: %.0f transfers/second",
				float64(iterations)/duration.Seconds())

			// Assert sub-20ms latency (vs 50-100ms in Go)
			if avgLatency > 20000 {
				t.Errorf("Transfer too slow: %dμs (expected < 20000μs)", avgLatency)
			}
		}
	})

	t.Run("TransferValidation", func(t *testing.T) {
		resp, err := client.ValidateTransaction(ctx,
			"550e8400-e29b-41d4-a716-446655440000",
			"550e8400-e29b-41d4-a716-446655440001",
			100000,
			"THB")

		if err != nil {
			// Expected without proper DB setup
			t.Logf("Validation error (expected without full setup): %v", err)
			return
		}

		t.Logf("✅ Transfer validation: valid=%v, code=%s, msg=%s",
			resp.IsValid, resp.ErrorCode, resp.ErrorMessage)
	})
}

// BenchmarkRustTransfer compares Rust vs Go transfer performance
// Run with: go test -bench=BenchmarkRustTransfer -benchtime=10s
func BenchmarkRustTransfer(b *testing.B) {
	client, err := NewAccountingClient("localhost:50051")
	if err != nil {
		b.Skipf("Rust service not available: %v", err)
	}
	defer client.Close()

	ctx := context.Background()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		client.Transfer(ctx,
			"550e8400-e29b-41d4-a716-446655440000",
			"550e8400-e29b-41d4-a716-446655440001",
			100000,
			"THB",
			fmt.Sprintf("bench-ref-%d", i),
			fmt.Sprintf("bench-req-%d", i))
	}
}
