package usecase

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// setupMockVerifyServer starts a mock HTTP server on a temporary Unix Domain Socket.
func setupMockVerifyServer(t testing.TB) (string, func()) {
	tmpDir, err := os.MkdirTemp("", "uds-test-*")
	require.NoError(t, err)

	udsPath := filepath.Join(tmpDir, "verify.sock")
	listener, err := net.Listen("unix", udsPath)
	require.NoError(t, err)

	mux := http.NewServeMux()
	mux.HandleFunc("/verify", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}

		bodyBytes, err := io.ReadAll(r.Body)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}

		var req VerifyRequest
		if err := json.Unmarshal(bodyBytes, &req); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		resp := VerifyResponse{
			IsValid: true,
		}
		respBytes, _ := json.Marshal(resp)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(respBytes)
	})

	server := &http.Server{
		Handler: mux,
	}

	go func() {
		_ = server.Serve(listener)
	}()

	cleanup := func() {
		_ = server.Close()
		_ = listener.Close()
		_ = os.RemoveAll(tmpDir)
	}

	return udsPath, cleanup
}

func TestVerifySignature(t *testing.T) {
	udsPath, cleanup := setupMockVerifyServer(t)
	defer cleanup()

	sigSvc := NewSignatureService(nil, udsPath)

	isValid, err := sigSvc.VerifySignature(context.Background(), "pkB64", "sigB64", "test-message")
	assert.NoError(t, err)
	assert.True(t, isValid)
}

// verifySignatureOldStyle simulates the unoptimized signature verification
// that instantiates a new HTTP Client and Transport on every call.
func verifySignatureOldStyle(ctx context.Context, udsPath, publicKeyB64, signatureB64, message string) (bool, error) {
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
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode != http.StatusOK {
		return false, fmt.Errorf("verify service returned status %d", resp.StatusCode)
	}

	var verifyResp VerifyResponse
	if err := json.NewDecoder(resp.Body).Decode(&verifyResp); err != nil {
		return false, err
	}

	return verifyResp.IsValid, nil
}

func BenchmarkVerifySignature_NewClientPerRequest(b *testing.B) {
	udsPath, cleanup := setupMockVerifyServer(b)
	defer cleanup()

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_, err := verifySignatureOldStyle(context.Background(), udsPath, "pkB64", "sigB64", "test-message")
		if err != nil {
			b.Fatalf("failed: %v", err)
		}
	}
}

func BenchmarkVerifySignature_ReusedClient(b *testing.B) {
	udsPath, cleanup := setupMockVerifyServer(b)
	defer cleanup()

	sigSvc := NewSignatureService(nil, udsPath)

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_, err := sigSvc.VerifySignature(context.Background(), "pkB64", "sigB64", "test-message")
		if err != nil {
			b.Fatalf("failed: %v", err)
		}
	}
}
