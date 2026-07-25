package usecase

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestSignature_VerifySignature_Success(t *testing.T) {
	// Setup a temporary UDS socket path
	tmpDir, err := os.MkdirTemp("", "sig_test_*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	socketPath := filepath.Join(tmpDir, "verify.sock")

	// Start a mock server on the Unix domain socket
	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		t.Fatalf("failed to listen on UDS: %v", err)
	}
	defer listener.Close()

	server := &http.Server{
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Method != "POST" || r.URL.Path != "/verify" {
				w.WriteHeader(http.StatusNotFound)
				return
			}
			var req VerifyRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}
			resp := VerifyResponse{
				IsValid: req.PublicKeyB64 == "valid-key" && req.SignatureB64 == "valid-sig" && req.Message == "hello",
			}
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(resp)
		}),
	}
	go func() {
		_ = server.Serve(listener)
	}()
	defer server.Shutdown(context.Background())

	// Create SignatureService pointing to the mock UDS
	sigService := NewSignatureService(nil, socketPath)

	// Test case 1: Valid signature
	isValid, err := sigService.VerifySignature(context.Background(), "valid-key", "valid-sig", "hello")
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if !isValid {
		t.Errorf("expected signature to be valid")
	}

	// Test case 2: Invalid signature (expected to return false and a verification error)
	isValid, err = sigService.VerifySignature(context.Background(), "invalid-key", "valid-sig", "hello")
	if isValid {
		t.Errorf("expected signature to be invalid, but got valid=true")
	}
	if err == nil {
		t.Errorf("expected verification error, but got nil error")
	}
}

func TestSignature_VerifyTimestampBucket(t *testing.T) {
	sigService := NewSignatureService(nil, "")

	// Current bucket
	currBucket := time.Now().Unix() / 60
	bucketStr := fmt.Sprintf("%d", currBucket)

	err := sigService.VerifyTimestampBucket(bucketStr)
	if err != nil {
		t.Errorf("expected current bucket to be valid, got: %v", err)
	}

	// Drift 1 min
	bucketStr = fmt.Sprintf("%d", currBucket-1)
	err = sigService.VerifyTimestampBucket(bucketStr)
	if err != nil {
		t.Errorf("expected bucket with 1 min drift to be valid, got: %v", err)
	}

	// Drift 3 mins (expired)
	bucketStr = fmt.Sprintf("%d", currBucket-3)
	err = sigService.VerifyTimestampBucket(bucketStr)
	if err == nil {
		t.Errorf("expected bucket with 3 mins drift to fail")
	}
}

func BenchmarkVerifySignature(b *testing.B) {
	tmpDir, err := os.MkdirTemp("", "sig_bench_*")
	if err != nil {
		b.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	socketPath := filepath.Join(tmpDir, "verify.sock")

	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		b.Fatalf("failed to listen on UDS: %v", err)
	}
	defer listener.Close()

	server := &http.Server{
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			resp := VerifyResponse{
				IsValid: true,
			}
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(resp)
		}),
	}
	go func() {
		_ = server.Serve(listener)
	}()
	defer server.Shutdown(context.Background())

	sigService := NewSignatureService(nil, socketPath)

	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			_, _ = sigService.VerifySignature(context.Background(), "pk", "sig", "msg")
		}
	})
}
