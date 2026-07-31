package usecase

import (
	"context"
	"encoding/json"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"testing"
	"time"
)

func TestSignatureService_VerifySignature(t *testing.T) {
	// Create a temporary directory for the socket file.
	tmpDir, err := os.MkdirTemp("", "verify-service-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	socketPath := filepath.Join(tmpDir, "verify_service.sock")

	// Set up the mock verify service over Unix domain socket.
	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		t.Fatalf("failed to listen on socket %s: %v", socketPath, err)
	}
	defer listener.Close()

	server := &http.Server{
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Method != http.MethodPost || r.URL.Path != "/verify" {
				w.WriteHeader(http.StatusNotFound)
				return
			}

			var req VerifyRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			w.Header().Set("Content-Type", "application/json")
			if req.Message == "valid" {
				json.NewEncoder(w).Encode(VerifyResponse{IsValid: true})
			} else {
				errMsg := "invalid signature"
				json.NewEncoder(w).Encode(VerifyResponse{IsValid: false, Error: &errMsg})
			}
		}),
	}

	go func() {
		if err := server.Serve(listener); err != nil && err != http.ErrServerClosed {
			t.Errorf("mock server failed: %v", err)
		}
	}()
	defer server.Close()

	// Wait briefly for the server to spin up.
	time.Sleep(10 * time.Millisecond)

	// Create SignatureService pointing to our mock UDS.
	svc := NewSignatureService(nil, socketPath)

	// Test successful verification.
	ok, err := svc.VerifySignature(context.Background(), "pubkey", "sig", "valid")
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if !ok {
		t.Error("expected verification to succeed")
	}

	// Test failed verification.
	ok, err = svc.VerifySignature(context.Background(), "pubkey", "sig", "invalid")
	if err == nil {
		t.Error("expected error for invalid signature")
	}
	if ok {
		t.Error("expected verification to fail")
	}
}

func TestSignatureService_VerifyTimestampBucket(t *testing.T) {
	svc := NewSignatureService(nil, "")

	// 1. Invalid timestamp format
	if err := svc.VerifyTimestampBucket("invalid-format"); err == nil {
		t.Error("expected error for invalid timestamp bucket format")
	}

	// 2. Valid timestamp (current bucket)
	currentBucketInt := time.Now().Unix() / 60
	currentBucketStr := strconv.FormatInt(currentBucketInt, 10)

	if err := svc.VerifyTimestampBucket(currentBucketStr); err != nil {
		t.Errorf("expected current bucket to be valid, got error: %v", err)
	}

	// 3. Acceptable drift (1 min ago)
	driftBucketStr := strconv.FormatInt(currentBucketInt-1, 10)
	if err := svc.VerifyTimestampBucket(driftBucketStr); err != nil {
		t.Errorf("expected 1-minute drift to be valid, got error: %v", err)
	}

	// 4. Expired timestamp bucket (5 mins ago)
	expiredBucketStr := strconv.FormatInt(currentBucketInt-5, 10)
	if err := svc.VerifyTimestampBucket(expiredBucketStr); err == nil {
		t.Error("expected 5-minute drift to be rejected, but it was accepted")
	}
}

func BenchmarkVerifySignature(b *testing.B) {
	tmpDir, err := os.MkdirTemp("", "verify-service-bench-*")
	if err != nil {
		b.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	socketPath := filepath.Join(tmpDir, "verify_service.sock")

	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		b.Fatalf("failed to listen on socket %s: %v", socketPath, err)
	}
	defer listener.Close()

	server := &http.Server{
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(VerifyResponse{IsValid: true})
		}),
	}

	go func() {
		_ = server.Serve(listener)
	}()
	defer server.Close()

	time.Sleep(10 * time.Millisecond)

	svc := NewSignatureService(nil, socketPath)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := svc.VerifySignature(context.Background(), "pubkey", "sig", "valid")
		if err != nil {
			b.Fatalf("unexpected error: %v", err)
		}
	}
}
