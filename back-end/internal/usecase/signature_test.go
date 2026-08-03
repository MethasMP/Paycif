package usecase

import (
	"context"
	"encoding/json"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"testing"
)

// setupMockUDSServer starts a mock HTTP server listening on a Unix domain socket.
// It returns the socket path and a cleanup function.
func setupMockUDSServer(t testing.TB) (string, func()) {
	tmpDir, err := os.MkdirTemp("", "uds-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}

	socketPath := filepath.Join(tmpDir, "verify_service.sock")
	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		os.RemoveAll(tmpDir)
		t.Fatalf("failed to listen on uds: %v", err)
	}

	server := &http.Server{
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Method == "POST" && r.URL.Path == "/verify" {
				w.Header().Set("Content-Type", "application/json")
				_ = json.NewEncoder(w).Encode(VerifyResponse{IsValid: true})
				return
			}
			w.WriteHeader(http.StatusNotFound)
		}),
	}

	go func() {
		_ = server.Serve(listener)
	}()

	cleanup := func() {
		_ = server.Shutdown(context.Background())
		_ = listener.Close()
		_ = os.RemoveAll(tmpDir)
	}

	return socketPath, cleanup
}

func TestVerifySignature(t *testing.T) {
	udsPath, cleanup := setupMockUDSServer(t)
	defer cleanup()

	svc := NewSignatureService(nil, udsPath)

	valid, err := svc.VerifySignature(context.Background(), "pubB64", "sigB64", "message")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !valid {
		t.Error("expected signature to be valid")
	}
}

func BenchmarkVerifySignature(b *testing.B) {
	udsPath, cleanup := setupMockUDSServer(b)
	defer cleanup()

	svc := NewSignatureService(nil, udsPath)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := svc.VerifySignature(context.Background(), "pubB64", "sigB64", "message")
		if err != nil {
			b.Fatalf("benchmark failed: %v", err)
		}
	}
}
