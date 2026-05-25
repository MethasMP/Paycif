package fxrpc

import (
	"context"
	"testing"
	"time"
)

// TestAccountingClientValidation tests input validation without requiring a running server
func TestAccountingClientValidation(t *testing.T) {
	// Create a mock client for validation tests (no actual connection)
	client := &AccountingClient{
		conn:    nil,
		client:  nil,
		address: "test:50051",
	}

	ctx := context.Background()

	t.Run("Transfer_EmptyFromWallet", func(t *testing.T) {
		_, err := client.Transfer(ctx, "", "to-wallet", 1000, "THB", "ref-1", "req-1")
		if err == nil {
			t.Error("expected error for empty from_wallet")
		}
		if err.Error() != "from_wallet is required" {
			t.Errorf("unexpected error: %v", err)
		}
	})

	t.Run("Transfer_EmptyToWallet", func(t *testing.T) {
		_, err := client.Transfer(ctx, "from-wallet", "", 1000, "THB", "ref-1", "req-1")
		if err == nil {
			t.Error("expected error for empty to_wallet")
		}
	})

	t.Run("Transfer_ZeroAmount", func(t *testing.T) {
		_, err := client.Transfer(ctx, "from-wallet", "to-wallet", 0, "THB", "ref-1", "req-1")
		if err == nil {
			t.Error("expected error for zero amount")
		}
	})

	t.Run("Transfer_NegativeAmount", func(t *testing.T) {
		_, err := client.Transfer(ctx, "from-wallet", "to-wallet", -100, "THB", "ref-1", "req-1")
		if err == nil {
			t.Error("expected error for negative amount")
		}
	})

	t.Run("Transfer_EmptyCurrency", func(t *testing.T) {
		_, err := client.Transfer(ctx, "from-wallet", "to-wallet", 1000, "", "ref-1", "req-1")
		if err == nil {
			t.Error("expected error for empty currency")
		}
	})

	t.Run("Transfer_EmptyReferenceID", func(t *testing.T) {
		_, err := client.Transfer(ctx, "from-wallet", "to-wallet", 1000, "THB", "", "req-1")
		if err == nil {
			t.Error("expected error for empty reference_id")
		}
	})

	t.Run("Transfer_EmptyRequestID", func(t *testing.T) {
		_, err := client.Transfer(ctx, "from-wallet", "to-wallet", 1000, "THB", "ref-1", "")
		if err == nil {
			t.Error("expected error for empty request_id")
		}
	})

	t.Run("GetBalance_EmptyWalletID", func(t *testing.T) {
		_, err := client.GetBalance(ctx, "", "req-1")
		if err == nil {
			t.Error("expected error for empty wallet_id")
		}
	})

	t.Run("GetBalance_EmptyRequestID", func(t *testing.T) {
		_, err := client.GetBalance(ctx, "wallet-1", "")
		if err == nil {
			t.Error("expected error for empty request_id")
		}
	})

	t.Run("ValidateTransaction_EmptyFromWallet", func(t *testing.T) {
		_, err := client.ValidateTransaction(ctx, "", "to-wallet", 1000, "THB")
		if err == nil {
			t.Error("expected error for empty from_wallet")
		}
	})

	t.Run("ValidateTransaction_ZeroAmount", func(t *testing.T) {
		_, err := client.ValidateTransaction(ctx, "from-wallet", "to-wallet", 0, "THB")
		if err == nil {
			t.Error("expected error for zero amount")
		}
	})
}

// TestDefaultClientConfig tests default configuration values
func TestDefaultClientConfig(t *testing.T) {
	cfg := DefaultClientConfig("localhost:50051")

	if cfg.Address != "localhost:50051" {
		t.Errorf("expected address localhost:50051, got %s", cfg.Address)
	}

	if cfg.ConnectTimeout != 10*time.Second {
		t.Errorf("expected connect timeout 10s, got %v", cfg.ConnectTimeout)
	}

	if cfg.RequestTimeout != 5*time.Second {
		t.Errorf("expected request timeout 5s, got %v", cfg.RequestTimeout)
	}

	if cfg.KeepAliveTime != 30*time.Second {
		t.Errorf("expected keepalive time 30s, got %v", cfg.KeepAliveTime)
	}

	if cfg.MaxRetries != 3 {
		t.Errorf("expected max retries 3, got %d", cfg.MaxRetries)
	}

	if !cfg.EnableHealthChecks {
		t.Error("expected health checks to be enabled by default")
	}
}

// TestNewAccountingClientWithConfig_EmptyAddress tests error handling for empty address
func TestNewAccountingClientWithConfig_EmptyAddress(t *testing.T) {
	cfg := &ClientConfig{
		Address:        "",
		ConnectTimeout: 5 * time.Second,
	}

	_, err := NewAccountingClientWithConfig(cfg)
	if err == nil {
		t.Error("expected error for empty address")
	}
	if err.Error() != "accounting-core address is required" {
		t.Errorf("unexpected error: %v", err)
	}
}

// TestAccountingClient_IsConnected tests connection state checking
func TestAccountingClient_IsConnected(t *testing.T) {
	client := &AccountingClient{
		conn:    nil,
		address: "test:50051",
	}

	if client.IsConnected() {
		t.Error("expected disconnected state for nil connection")
	}
}

// TestAccountingClient_GetAddress tests address getter
func TestAccountingClient_GetAddress(t *testing.T) {
	client := &AccountingClient{
		address: "localhost:50051",
	}

	if client.GetAddress() != "localhost:50051" {
		t.Errorf("expected localhost:50051, got %s", client.GetAddress())
	}
}

// TestAccountingClient_Close_NilConn tests closing nil connection
func TestAccountingClient_Close_NilConn(t *testing.T) {
	client := &AccountingClient{
		conn: nil,
	}

	err := client.Close()
	if err != nil {
		t.Errorf("expected no error closing nil connection, got %v", err)
	}
}
