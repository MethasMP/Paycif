package main

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"testing"
	"time"

	pb "paysif/internal/adapter/grpc/pb"

	"github.com/google/uuid"
	"github.com/shopspring/decimal"
)

func TestFXEngineServer_FindRate(t *testing.T) {
	srv := NewFXEngineServer(nil, nil, 3600)

	// Direct
	rate, src, _, ok := srv.findRate("USD", "THB")
	if !ok || !rate.Equal(decimal.NewFromFloat(35.50)) {
		t.Fatalf("expected 35.50 for USD:THB, got %v (ok=%v, src=%s)", rate, ok, src)
	}

	// Inverse
	srv.rates.Store("EUR:USD", CachedRate{
		Rate:        decimal.NewFromFloat(1.10),
		LastUpdated: time.Now().Unix(),
		ExpiresAt:   time.Now().Unix() + 3600,
		Source:      "ECB",
	})
	_, _, _, ok = srv.findRate("USD", "EUR")
	if !ok {
		t.Fatalf("expected inverse rate for USD:EUR")
	}

	// Cross rate
	srv.rates.Store("EUR:THB", CachedRate{
		Rate:        decimal.NewFromFloat(38.50),
		LastUpdated: time.Now().Unix(),
		ExpiresAt:   time.Now().Unix() + 3600,
		Source:      "ECB",
	})
	_, src, _, ok = srv.findRate("USD", "THB")
	if !ok {
		t.Fatalf("expected cross rate for USD:THB")
	}
	if src != "default" && src != "ECB-inverted+ECB-cross" {
		t.Logf("Cross rate source: %s", src)
	}
}

func TestFXEngineServer_PreValidateTransfer_LimitExceeded(t *testing.T) {
	srv := NewFXEngineServer(nil, nil, 3600)
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("failed to generate key: %v", err)
	}

	msg := []byte("test message")
	sig := ed25519.Sign(priv, msg)
	userID := uuid.New().String()

	ctx := context.Background()

	// Fill daily limit
	uid, _ := uuid.Parse(userID)
	_, _, _ = srv.limitCache.CheckAndReserveLimit(ctx, uid, 1950000) // ฿19,500 reserved

	req := &pb.PreValidateTransferRequest{
		UserId:    userID,
		Amount:    100000, // ฿1,000 exceeds remaining ฿500
		PublicKey: pub,
		Signature: sig,
		Message:   msg,
	}

	resp, err := srv.PreValidateTransfer(ctx, req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Valid {
		t.Fatalf("expected transfer to be rejected")
	}
	expectedMsg := "Daily limit exceeded. Remaining: 500.00"
	if resp.ErrorMessage != expectedMsg {
		t.Errorf("expected error message %q, got %q", expectedMsg, resp.ErrorMessage)
	}
}

func BenchmarkFXEngineServer_FindRateCross(b *testing.B) {
	srv := NewFXEngineServer(nil, nil, 3600)
	srv.rates.Store("EUR:USD", CachedRate{
		Rate:        decimal.NewFromFloat(1.0850),
		LastUpdated: time.Now().Unix(),
		ExpiresAt:   time.Now().Unix() + 3600,
		Source:      "ECB",
	})
	srv.rates.Store("EUR:THB", CachedRate{
		Rate:        decimal.NewFromFloat(38.50),
		LastUpdated: time.Now().Unix(),
		ExpiresAt:   time.Now().Unix() + 3600,
		Source:      "Mock",
	})

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_, _, _, _ = srv.findRate("USD", "THB")
	}
}

func BenchmarkFXEngineServer_PreValidateTransfer_LimitExceeded(b *testing.B) {
	srv := NewFXEngineServer(nil, nil, 3600)
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		b.Fatalf("failed to generate key: %v", err)
	}

	msg := []byte("test message")
	sig := ed25519.Sign(priv, msg)
	userID := uuid.New().String()
	ctx := context.Background()

	uid, _ := uuid.Parse(userID)
	_, _, _ = srv.limitCache.CheckAndReserveLimit(ctx, uid, 2000000) // Daily limit maxed

	req := &pb.PreValidateTransferRequest{
		UserId:    userID,
		Amount:    100000,
		PublicKey: pub,
		Signature: sig,
		Message:   msg,
	}

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_, _ = srv.PreValidateTransfer(ctx, req)
	}
}
