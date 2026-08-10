package usecase

import (
	"bytes"
	"context"
	"encoding/json"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// setupMockUDSServer boots a mock UDS listener returning expected verify responses
func setupMockUDSServer(t *testing.T) (string, func()) {
	tmpDir, err := os.MkdirTemp("", "verify-service-test")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	socketPath := filepath.Join(tmpDir, "verify_service_test.sock")

	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		os.RemoveAll(tmpDir)
		t.Fatalf("failed to listen on UDS: %v", err)
	}

	server := &http.Server{
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path != "/verify" || r.Method != http.MethodPost {
				w.WriteHeader(http.StatusNotFound)
				return
			}

			var req VerifyRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)

			var resp VerifyResponse
			if req.Message == "valid_msg" {
				resp.IsValid = true
			} else if req.Message == "error_msg" {
				resp.IsValid = false
				errMsg := "custom verify error"
				resp.Error = &errMsg
			} else {
				resp.IsValid = false
			}
			_ = json.NewEncoder(w).Encode(resp)
		}),
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

func TestVerifySignature_Success(t *testing.T) {
	socketPath, cleanup := setupMockUDSServer(t)
	defer cleanup()

	svc := NewSignatureService(nil, socketPath)
	ok, err := svc.VerifySignature(context.Background(), "pub_key", "sig", "valid_msg")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !ok {
		t.Errorf("expected signature to be valid")
	}
}

func TestVerifySignature_Invalid(t *testing.T) {
	socketPath, cleanup := setupMockUDSServer(t)
	defer cleanup()

	svc := NewSignatureService(nil, socketPath)
	ok, err := svc.VerifySignature(context.Background(), "pub_key", "sig", "invalid_msg")
	if err == nil {
		t.Fatalf("expected an error on invalid signature verification")
	}
	if ok {
		t.Errorf("expected signature to be invalid")
	}
}

func TestVerifySignature_WithErrorMsg(t *testing.T) {
	socketPath, cleanup := setupMockUDSServer(t)
	defer cleanup()

	svc := NewSignatureService(nil, socketPath)
	ok, err := svc.VerifySignature(context.Background(), "pub_key", "sig", "error_msg")
	if err == nil {
		t.Fatalf("expected an error on custom verify error message")
	}
	if !bytes.Contains([]byte(err.Error()), []byte("custom verify error")) {
		t.Errorf("expected error to contain 'custom verify error', got %v", err)
	}
	if ok {
		t.Errorf("expected signature to be invalid")
	}
}

func BenchmarkSignatureVerification_Unoptimized(b *testing.B) {
	// Replicates original unoptimized behavior (creating client/transport on every request)
	socketPath, cleanup := setupMockUDSServer(&testing.T{})
	defer cleanup()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		client := &http.Client{
			Transport: &http.Transport{
				DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
					var d net.Dialer
					return d.DialContext(ctx, "unix", socketPath)
				},
			},
			Timeout: 200 * time.Millisecond,
		}

		verifyReq := VerifyRequest{
			PublicKeyB64: "pub_key",
			SignatureB64: "sig",
			Message:      "valid_msg",
		}
		reqBytes, _ := json.Marshal(verifyReq)
		req, _ := http.NewRequestWithContext(context.Background(), "POST", "http://localhost/verify", bytes.NewReader(reqBytes))
		req.Header.Set("Content-Type", "application/json")

		resp, err := client.Do(req)
		if err != nil {
			b.Fatalf("failed to request: %v", err)
		}
		resp.Body.Close()
	}
}

func BenchmarkSignatureVerification_Optimized(b *testing.B) {
	// Measures new optimized behavior (reusing single pre-allocated client/transport)
	socketPath, cleanup := setupMockUDSServer(&testing.T{})
	defer cleanup()

	svc := NewSignatureService(nil, socketPath)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		ok, err := svc.VerifySignature(context.Background(), "pub_key", "sig", "valid_msg")
		if err != nil {
			b.Fatalf("failed to verify signature: %v", err)
		}
		if !ok {
			b.Fatalf("expected signature to be valid")
		}
	}
}
