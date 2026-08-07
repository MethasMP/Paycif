package usecase

import (
	"bytes"
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

// setupMockUDSServer starts a mock HTTP server listening on a Unix Domain Socket (UDS)
// and returns the socket path and a cleanup function.
func setupMockUDSServer(t *testing.T, handler http.Handler) (string, func()) {
	t.Helper()

	tmpDir, err := os.MkdirTemp("", "sigsvc-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}

	socketPath := filepath.Join(tmpDir, "verify_service.sock")
	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		os.RemoveAll(tmpDir)
		t.Fatalf("failed to listen on UDS socket: %v", err)
	}

	server := &http.Server{
		Handler: handler,
	}

	go func() {
		_ = server.Serve(listener)
	}()

	cleanup := func() {
		_ = server.Close()
		_ = listener.Close()
		os.RemoveAll(tmpDir)
	}

	return socketPath, cleanup
}

func TestSignatureService_VerifySignature_Success(t *testing.T) {
	mockHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/verify" {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		var req VerifyRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		if req.SignatureB64 == "valid-sig" {
			_ = json.NewEncoder(w).Encode(VerifyResponse{IsValid: true})
		} else {
			errMsg := "invalid signature"
			_ = json.NewEncoder(w).Encode(VerifyResponse{IsValid: false, Error: &errMsg})
		}
	})

	socketPath, cleanup := setupMockUDSServer(t, mockHandler)
	defer cleanup()

	svc := NewSignatureService(nil, socketPath)

	isValid, err := svc.VerifySignature(context.Background(), "some-pubkey", "valid-sig", "hello")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !isValid {
		t.Error("expected signature to be valid")
	}

	isValid, err = svc.VerifySignature(context.Background(), "some-pubkey", "invalid-sig", "hello")
	if err == nil {
		t.Error("expected verification to fail and return an error")
	}
	if isValid {
		t.Error("expected signature to be invalid")
	}
}

func TestSignatureService_VerifyTimestampBucket(t *testing.T) {
	svc := NewSignatureService(nil, "")

	// 1. Valid bucket (current minute)
	currentBucket := time.Now().Unix() / 60
	err := svc.VerifyTimestampBucket(strconv.FormatInt(currentBucket, 10))
	if err != nil {
		t.Errorf("unexpected error for current bucket: %v", err)
	}

	// 2. Valid bucket with slight drift (e.g. +1 min)
	err = svc.VerifyTimestampBucket(strconv.FormatInt(currentBucket+1, 10))
	if err != nil {
		t.Errorf("unexpected error for +1 drift: %v", err)
	}

	// 3. Invalid bucket with extreme drift (e.g. +5 mins)
	err = svc.VerifyTimestampBucket(strconv.FormatInt(currentBucket+5, 10))
	if err == nil {
		t.Error("expected error for extreme drift")
	}

	// 4. Invalid bucket format
	err = svc.VerifyTimestampBucket("not-a-number")
	if err == nil {
		t.Error("expected error for non-numeric bucket")
	}

	// 5. Empty bucket
	err = svc.VerifyTimestampBucket("")
	if err == nil {
		t.Error("expected error for empty bucket")
	}
}

// verifySignatureUnoptimized simulates the old behaviour where a new http.Client/http.Transport is allocated on every call.
func verifySignatureUnoptimized(ctx context.Context, udsPath string, publicKeyB64, signatureB64, message string) (bool, error) {
	client := &http.Client{
		Transport: &http.Transport{
			DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
				var d net.Dialer
				return d.DialContext(ctx, "unix", udsPath)
			},
		},
		Timeout: 200 * time.Millisecond,
	}

	verifyReq := VerifyRequest{
		PublicKeyB64: publicKeyB64,
		SignatureB64: signatureB64,
		Message:      message,
	}
	reqBytes, err := json.Marshal(verifyReq)
	if err != nil {
		return false, err
	}

	req, err := http.NewRequestWithContext(ctx, "POST", "http://localhost/verify", bytes.NewReader(reqBytes))
	if err != nil {
		return false, err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()

	var verifyResp VerifyResponse
	if err := json.NewDecoder(resp.Body).Decode(&verifyResp); err != nil {
		return false, err
	}

	return verifyResp.IsValid, nil
}

func BenchmarkSignatureService_Compare(b *testing.B) {
	mockHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(VerifyResponse{IsValid: true})
	})

	// Use a standard testing setup style but for benchmark
	tmpDir, err := os.MkdirTemp("", "sigsvc-bench-*")
	if err != nil {
		b.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	socketPath := filepath.Join(tmpDir, "verify_service.sock")
	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		b.Fatalf("failed to listen on UDS socket: %v", err)
	}

	server := &http.Server{Handler: mockHandler}
	go func() { _ = server.Serve(listener) }()
	defer func() {
		_ = server.Close()
		_ = listener.Close()
	}()

	ctx := context.Background()

	b.Run("Unoptimized (Alloc-Per-Call)", func(b *testing.B) {
		b.ReportAllocs()
		for i := 0; i < b.N; i++ {
			_, err := verifySignatureUnoptimized(ctx, socketPath, "pubkey", "sig", "msg")
			if err != nil {
				b.Fatalf("verification failed: %v", err)
			}
		}
	})

	b.Run("Optimized (Reused-Client)", func(b *testing.B) {
		svc := NewSignatureService(nil, socketPath)
		b.ReportAllocs()
		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			_, err := svc.VerifySignature(ctx, "pubkey", "sig", "msg")
			if err != nil {
				b.Fatalf("verification failed: %v", err)
			}
		}
	})
}
