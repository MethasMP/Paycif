package fxrpc

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"os"
	"sync"
	"time"

	fx_pb "paysif/internal/grpc/pb"

	"github.com/shopspring/decimal"
	"google.golang.org/grpc"
	"google.golang.org/grpc/backoff"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/keepalive"
)

// FXClient wraps gRPC connection to Rust FX Engine
// with production-ready features: connection pooling, retries, and legacy support.
type FXClient struct {
	conn    *grpc.ClientConn
	client  fx_pb.FXServiceClient
	address string
	mu      sync.RWMutex
}

// FXClientInterface defines the interface for FX operations to allow mocking
type FXClientInterface interface {
	Convert(ctx context.Context, fromCurrency, toCurrency string, amount int64, requestID string) (*fx_pb.ConvertResponse, error)
	GetRate(ctx context.Context, fromCurrency, toCurrency, requestID string) (*fx_pb.RateResponse, error)
	GetAllRates(ctx context.Context, baseCurrency, requestID string) (*fx_pb.AllRatesResponse, error)
	HealthCheck(ctx context.Context) (*fx_pb.FXHealthResponse, error)
	UpdateRate(ctx context.Context, from, to string, rate decimal.Decimal, source string) error
	VerifySignature(ctx context.Context, publicKey, signature, message []byte) (*fx_pb.VerifySignatureResponse, error)
	GetLimits(ctx context.Context, userID, currency string) (*fx_pb.GetLimitsResponse, error)
	PreValidateTransfer(ctx context.Context, userID, currency string, amount int64, publicKey, signature, message []byte) (*fx_pb.PreValidateTransferResponse, error)
}

// FXClientConfig holds configuration for the FX client
type FXClientConfig struct {
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

// GetClient returns the underlying gRPC client.
func (c *FXClient) GetClient() fx_pb.FXServiceClient {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.client
}

// DefaultFXClientConfig returns production-ready default configuration
func DefaultFXClientConfig(address string) *FXClientConfig {
	return &FXClientConfig{
		Address:            address,
		ConnectTimeout:     10 * time.Second,
		RequestTimeout:     5 * time.Second,
		KeepAliveTime:      30 * time.Second,
		KeepAliveTimeout:   10 * time.Second,
		MaxRetries:         3,
		EnableHealthChecks: true,
		EnableTLS:          false, // Default to insecure for local dev
	}
}

// NewFXClient creates a new high-level FX client with defaults
func NewFXClient(address string) (*FXClient, error) {
	return NewFXClientWithConfig(DefaultFXClientConfig(address))
}

// NewFXClientWithConfig creates a connection with custom configuration
func NewFXClientWithConfig(cfg *FXClientConfig) (*FXClient, error) {
	if cfg.Address == "" {
		return nil, fmt.Errorf("fx-engine address is required")
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
		// Advanced Resilience: Method-Level Retry Policy
		// This keeps the "pipe" alive even if requests fail transiently (e.g. during Rust restart)
		grpc.WithDefaultServiceConfig(`{
			"methodConfig": [{
				"name": [{"service": "fx.FXService"}],
				"retryPolicy": {
					"MaxAttempts": 5,
					"InitialBackoff": "0.1s",
					"MaxBackoff": "1s",
					"BackoffMultiplier": 2,
					"RetryableStatusCodes": ["UNAVAILABLE", "UNKNOWN"]
				}
			}]
		}`),
	}

	conn, err := grpc.DialContext(ctx, cfg.Address, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to init grpc connection at %s: %w", cfg.Address, err)
	}

	client := &FXClient{
		conn:    conn,
		client:  fx_pb.NewFXServiceClient(conn),
		address: cfg.Address,
	}

	// Verify connection with health check asynchronously if enabled
	if cfg.EnableHealthChecks {
		go func() {
			healthCtx, healthCancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer healthCancel()

			_, _ = client.HealthCheck(healthCtx)
			// Non-fatal if it fails during boot; gRPC will keep trying in bg
		}()
	}

	return client, nil
}

// Close closes the gRPC connection gracefully
func (c *FXClient) Close() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.conn != nil {
		return c.conn.Close()
	}
	return nil
}

// IsConnected checks if the client is still connected
func (c *FXClient) IsConnected() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if c.conn == nil {
		return false
	}
	state := c.conn.GetState()
	return state.String() == "READY" || state.String() == "IDLE"
}

// Convert converts amount from one currency to another
func (c *FXClient) Convert(ctx context.Context, fromCurrency, toCurrency string, amount int64, requestID string) (*fx_pb.ConvertResponse, error) {
	if fromCurrency == "" || toCurrency == "" {
		return nil, fmt.Errorf("currency codes are required")
	}
	if amount <= 0 {
		return nil, fmt.Errorf("amount must be positive")
	}

	return c.client.Convert(ctx, &fx_pb.ConvertRequest{
		FromCurrency: fromCurrency,
		ToCurrency:   toCurrency,
		Amount:       amount,
		RequestId:    requestID,
	})
}

// GetRate gets the exchange rate between two currencies
func (c *FXClient) GetRate(ctx context.Context, fromCurrency, toCurrency, requestID string) (*fx_pb.RateResponse, error) {
	if fromCurrency == "" || toCurrency == "" {
		return nil, fmt.Errorf("currency codes are required")
	}

	return c.client.GetRate(ctx, &fx_pb.RateRequest{
		FromCurrency: fromCurrency,
		ToCurrency:   toCurrency,
		RequestId:    requestID,
	})
}

// GetAllRates gets all exchange rates for a base currency
func (c *FXClient) GetAllRates(ctx context.Context, baseCurrency, requestID string) (*fx_pb.AllRatesResponse, error) {
	if baseCurrency == "" {
		return nil, fmt.Errorf("base currency is required")
	}

	return c.client.GetAllRates(ctx, &fx_pb.AllRatesRequest{
		BaseCurrency: baseCurrency,
		RequestId:    requestID,
	})
}

// HealthCheck checks if FX Engine is healthy
func (c *FXClient) HealthCheck(ctx context.Context) (*fx_pb.FXHealthResponse, error) {
	return c.client.HealthCheck(ctx, &fx_pb.FXHealthRequest{})
}

// UpdateRate updates a rate in the FX Engine (Administrative/Control Plane)
func (c *FXClient) UpdateRate(ctx context.Context, from, to string, rate decimal.Decimal, source string) error {
	_, err := c.client.UpdateRate(ctx, &fx_pb.UpdateRateRequest{
		FromCurrency: from,
		ToCurrency:   to,
		Rate:         rate.String(),
		Source:       source,
	})
	return err
}

// VerifySignature offloads cryptographic verification to the Rust engine (Ed25519-SIMD)
func (c *FXClient) VerifySignature(ctx context.Context, publicKey, signature, message []byte) (*fx_pb.VerifySignatureResponse, error) {
	if len(publicKey) == 0 || len(signature) == 0 || len(message) == 0 {
		return nil, fmt.Errorf("public key, signature, and message are all required")
	}

	return c.client.VerifySignature(ctx, &fx_pb.VerifySignatureRequest{
		PublicKey: publicKey,
		Signature: signature,
		Message:   message,
	})
}

// GetLimits returns the remaining limits for a user
func (c *FXClient) GetLimits(ctx context.Context, userID, currency string) (*fx_pb.GetLimitsResponse, error) {
	if userID == "" || currency == "" {
		return nil, fmt.Errorf("user ID and currency are required")
	}

	return c.client.GetLimits(ctx, &fx_pb.GetLimitsRequest{
		UserId:   userID,
		Currency: currency,
	})
}

// PreValidateTransfer checks both signature validity and limit constraints in one optimized call
func (c *FXClient) PreValidateTransfer(ctx context.Context, userID, currency string, amount int64, publicKey, signature, message []byte) (*fx_pb.PreValidateTransferResponse, error) {
	if userID == "" || amount <= 0 {
		return nil, fmt.Errorf("invalid request parameters")
	}

	return c.client.PreValidateTransfer(ctx, &fx_pb.PreValidateTransferRequest{
		UserId:    userID,
		Currency:  currency,
		Amount:    amount,
		PublicKey: publicKey,
		Signature: signature,
		Message:   message,
	})
}

// GetAddress returns the configured server address
func (c *FXClient) GetAddress() string {
	return c.address
}
