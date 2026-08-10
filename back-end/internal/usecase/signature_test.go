package usecase

import (
	"context"
	"encoding/json"
	"net"
	"net/http"
	"os"
	"testing"
)

func TestVerifySignature(t *testing.T) {
	udsPath := "/tmp/test_verify_service.sock"
	_ = os.Remove(udsPath)
	listener, err := net.Listen("unix", udsPath)
	if err != nil {
		t.Fatalf("failed to listen on uds: %v", err)
	}
	defer listener.Close()
	defer os.Remove(udsPath)

	server := &http.Server{
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			var req VerifyRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(VerifyResponse{IsValid: true})
		}),
	}
	go func() {
		_ = server.Serve(listener)
	}()
	defer func() {
		_ = server.Close()
	}()

	svc := NewSignatureService(nil, udsPath)
	valid, err := svc.VerifySignature(context.Background(), "pubkey", "sig", "msg")
	if err != nil {
		t.Fatalf("VerifySignature failed: %v", err)
	}
	if !valid {
		t.Errorf("expected signature to be valid")
	}
}

func BenchmarkVerifySignature(b *testing.B) {
	udsPath := "/tmp/bench_verify_service.sock"
	_ = os.Remove(udsPath)
	listener, err := net.Listen("unix", udsPath)
	if err != nil {
		b.Fatalf("failed to listen on uds: %v", err)
	}
	defer listener.Close()
	defer os.Remove(udsPath)

	server := &http.Server{
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			var req VerifyRequest
			_ = json.NewDecoder(r.Body).Decode(&req)
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(VerifyResponse{IsValid: true})
		}),
	}
	go func() {
		_ = server.Serve(listener)
	}()
	defer func() {
		_ = server.Close()
	}()

	svc := NewSignatureService(nil, udsPath)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := svc.VerifySignature(context.Background(), "pubkey", "sig", "msg")
		if err != nil {
			b.Fatalf("VerifySignature failed: %v", err)
		}
	}
}
