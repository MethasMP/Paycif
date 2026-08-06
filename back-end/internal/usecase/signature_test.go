package usecase

import (
	"context"
	"encoding/json"
	"net"
	"net/http"
	"os"
	"testing"
	"time"
)

func TestSignatureService_VerifySignature(t *testing.T) {
	// Create a temporary Unix domain socket path
	socketFile, err := os.CreateTemp("", "verify_service_*.sock")
	if err != nil {
		t.Fatalf("failed to create temp file for socket: %v", err)
	}
	socketPath := socketFile.Name()
	_ = os.Remove(socketPath) // Remove the file so net.Listen can bind to it
	defer func() { _ = os.Remove(socketPath) }()

	// Start a mock UDS HTTP server
	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		t.Fatalf("failed to listen on uds socket: %v", err)
	}
	defer func() { _ = listener.Close() }()

	server := &http.Server{
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path != "/verify" {
				http.NotFound(w, r)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)
			_ = json.NewEncoder(w).Encode(VerifyResponse{IsValid: true})
		}),
	}
	go func() {
		_ = server.Serve(listener)
	}()
	defer func() { _ = server.Shutdown(context.Background()) }()

	// Wait for listener to be ready
	time.Sleep(20 * time.Millisecond)

	// Create SignatureService
	svc := NewSignatureService(nil, socketPath)

	// Verify signature
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	ok, err := svc.VerifySignature(ctx, "pubkey", "sig", "msg")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !ok {
		t.Errorf("expected signature to be valid")
	}
}

func BenchmarkVerifySignature(b *testing.B) {
	// Create a temporary Unix domain socket path
	socketFile, err := os.CreateTemp("", "verify_service_bench_*.sock")
	if err != nil {
		b.Fatalf("failed to create temp file for socket: %v", err)
	}
	socketPath := socketFile.Name()
	_ = os.Remove(socketPath) // Remove the file so net.Listen can bind to it
	defer func() { _ = os.Remove(socketPath) }()

	// Start a mock UDS HTTP server
	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		b.Fatalf("failed to listen on uds socket: %v", err)
	}
	defer func() { _ = listener.Close() }()

	server := &http.Server{
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)
			_ = json.NewEncoder(w).Encode(VerifyResponse{IsValid: true})
		}),
	}
	go func() {
		_ = server.Serve(listener)
	}()
	defer func() { _ = server.Shutdown(context.Background()) }()

	// Wait for listener to be ready
	time.Sleep(20 * time.Millisecond)

	svc := NewSignatureService(nil, socketPath)

	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		ctx := context.Background()
		for pb.Next() {
			_, err := svc.VerifySignature(ctx, "pubkey", "sig", "msg")
			if err != nil {
				b.Errorf("unexpected error: %v", err)
			}
		}
	})
}
