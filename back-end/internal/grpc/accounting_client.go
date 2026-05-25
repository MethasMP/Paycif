package fxrpc

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"os"
	"sync"
	"time"

	pb "paysif/internal/grpc/pb"

	"google.golang.org/grpc"
	"google.golang.org/grpc/backoff"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/keepalive"
)

// AccountingClient wraps gRPC connection to Rust Accounting Core
// with production-ready features: connection pooling, retries, and health monitoring.
type AccountingClient struct {
	conn    *grpc.ClientConn
	client  pb.AccountingServiceClient
	address string
	mu      sync.RWMutex
}

// ClientConfig holds configuration for the accounting client
type ClientConfig struct {
	Address            string
	ConnectTimeout     time.Duration
	RequestTimeout     time.Duration
	KeepAliveTime      time.Duration
	KeepAliveTimeout   time.Duration
	MaxRetries         int
	EnableHealthChecks bool
	// TLS Configuration
	EnableTLS      bool
	CACertPath     string
	ClientCertPath string
	ClientKeyPath  string
}

// DefaultClientConfig returns production-ready default configuration
func DefaultClientConfig(address string) *ClientConfig {
	return &ClientConfig{
		Address:            address,
		ConnectTimeout:     10 * time.Second,
		RequestTimeout:     5 * time.Second,
		KeepAliveTime:      30 * time.Second,
		KeepAliveTimeout:   10 * time.Second,
		MaxRetries:         3,
		EnableHealthChecks: true,
		EnableTLS:          false, // Default to insecure for local dev unless specified
	}
}

// NewAccountingClient creates a connection to Rust gRPC service with production defaults
func NewAccountingClient(address string) (*AccountingClient, error) {
	return NewAccountingClientWithConfig(DefaultClientConfig(address))
}

// NewAccountingClientWithConfig creates a connection with custom configuration
func NewAccountingClientWithConfig(cfg *ClientConfig) (*AccountingClient, error) {
	if cfg.Address == "" {
		return nil, fmt.Errorf("accounting-core address is required")
	}

	ctx, cancel := context.WithTimeout(context.Background(), cfg.ConnectTimeout)
	defer cancel()

	// Transport Credentials
	var creds credentials.TransportCredentials
	if cfg.EnableTLS {
		// mTLS Configuration
		certificate, err := tls.LoadX509KeyPair(cfg.ClientCertPath, cfg.ClientKeyPath)
		if err != nil {
			return nil, fmt.Errorf("failed to load client certs: %w", err)
		}

		caCert, err := os.ReadFile(cfg.CACertPath)
		if err != nil {
			return nil, fmt.Errorf("failed to read CA cert: %w", err)
		}

		caCertPool := x509.NewCertPool()
		if !caCertPool.AppendCertsFromPEM(caCert) {
			return nil, fmt.Errorf("failed to append CA cert")
		}

		tlsConfig := &tls.Config{
			Certificates: []tls.Certificate{certificate},
			RootCAs:      caCertPool,
			MinVersion:   tls.VersionTLS13, // Force TLS 1.3
		}
		creds = credentials.NewTLS(tlsConfig)
	} else {
		creds = insecure.NewCredentials()
	}

	// Production-ready gRPC options
	opts := []grpc.DialOption{
		grpc.WithTransportCredentials(creds),
		grpc.WithBlock(),
		// Keepalive for long-running connections
		grpc.WithKeepaliveParams(keepalive.ClientParameters{
			Time:                cfg.KeepAliveTime,
			Timeout:             cfg.KeepAliveTimeout,
			PermitWithoutStream: true,
		}),
		// Backoff configuration for retries
		grpc.WithConnectParams(grpc.ConnectParams{
			Backoff: backoff.Config{
				BaseDelay:  100 * time.Millisecond,
				Multiplier: 1.6,
				Jitter:     0.2,
				MaxDelay:   3 * time.Second,
			},
			MinConnectTimeout: cfg.ConnectTimeout,
		}),
		// Default call options
		grpc.WithDefaultCallOptions(
			grpc.MaxCallRecvMsgSize(4*1024*1024), // 4MB max message
			grpc.MaxCallSendMsgSize(4*1024*1024),
		),
	}

	conn, err := grpc.DialContext(ctx, cfg.Address, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to accounting-core at %s: %w", cfg.Address, err)
	}

	client := &AccountingClient{
		conn:    conn,
		client:  pb.NewAccountingServiceClient(conn),
		address: cfg.Address,
	}

	// Verify connection with health check if enabled
	if cfg.EnableHealthChecks {
		healthCtx, healthCancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer healthCancel()

		resp, err := client.HealthCheck(healthCtx)
		if err != nil {
			conn.Close()
			return nil, fmt.Errorf("health check failed for accounting-core: %w", err)
		}
		if !resp.Healthy {
			conn.Close()
			return nil, fmt.Errorf("accounting-core reported unhealthy status")
		}
	}

	return client, nil
}

// Close closes the gRPC connection gracefully
func (c *AccountingClient) Close() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.conn != nil {
		return c.conn.Close()
	}
	return nil
}

// IsConnected checks if the client is still connected
func (c *AccountingClient) IsConnected() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if c.conn == nil {
		return false
	}
	state := c.conn.GetState()
	return state.String() == "READY" || state.String() == "IDLE"
}

// Transfer executes an atomic double-entry transfer via Rust.
// Returns TransferResponse with success status and error details if failed.
func (c *AccountingClient) Transfer(ctx context.Context, fromWallet, toWallet string, amount int64, currency, referenceID, requestID string) (*pb.TransferResponse, error) {
	// Input validation
	if fromWallet == "" {
		return nil, fmt.Errorf("from_wallet is required")
	}
	if toWallet == "" {
		return nil, fmt.Errorf("to_wallet is required")
	}
	if amount <= 0 {
		return nil, fmt.Errorf("amount must be positive")
	}
	if currency == "" {
		return nil, fmt.Errorf("currency is required")
	}
	if referenceID == "" {
		return nil, fmt.Errorf("reference_id is required for idempotency")
	}
	if requestID == "" {
		return nil, fmt.Errorf("request_id is required for tracing")
	}

	return c.client.Transfer(ctx, &pb.TransferRequest{
		FromWalletId: fromWallet,
		ToWalletId:   toWallet,
		Amount:       amount,
		Currency:     currency,
		ReferenceId:  referenceID,
		RequestId:    requestID,
	})
}

// GetBalance retrieves wallet balance via Rust
func (c *AccountingClient) GetBalance(ctx context.Context, walletID, requestID string) (*pb.BalanceResponse, error) {
	if walletID == "" {
		return nil, fmt.Errorf("wallet_id is required")
	}
	if requestID == "" {
		return nil, fmt.Errorf("request_id is required for tracing")
	}

	return c.client.GetBalance(ctx, &pb.BalanceRequest{
		WalletId:  walletID,
		RequestId: requestID,
	})
}

// ValidateTransaction checks if a transfer would succeed without executing.
// Use this for pre-flight checks before user confirmation.
func (c *AccountingClient) ValidateTransaction(ctx context.Context, fromWallet, toWallet string, amount int64, currency string) (*pb.ValidationResponse, error) {
	if fromWallet == "" {
		return nil, fmt.Errorf("from_wallet is required")
	}
	if amount <= 0 {
		return nil, fmt.Errorf("amount must be positive")
	}

	return c.client.ValidateTransaction(ctx, &pb.TransferRequest{
		FromWalletId: fromWallet,
		ToWalletId:   toWallet,
		Amount:       amount,
		Currency:     currency,
	})
}

// HealthCheck checks if Rust service is healthy
func (c *AccountingClient) HealthCheck(ctx context.Context) (*pb.HealthResponse, error) {
	return c.client.HealthCheck(ctx, &pb.HealthRequest{})
}

// GetAddress returns the configured server address
func (c *AccountingClient) GetAddress() string {
	return c.address
}
