package usecase

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"sync"
	"time"

	"github.com/google/uuid"
)

type keyCacheEntry struct {
	publicKey string
	expiresAt time.Time
}

// SignatureService handles Ed25519 signature verification via the Go verify-service.
type SignatureService struct {
	DB      *sql.DB
	udsPath string
	cache   sync.Map
	client  *http.Client
}

// NewSignatureService creates a new SignatureService injecting dependencies.
func NewSignatureService(db *sql.DB, udsPath string) *SignatureService {
	if udsPath == "" {
		udsPath = "/tmp/verify_service.sock"
	}

	// Initialize and reuse a single thread-safe http.Client and Transport for UDS
	transport := &http.Transport{
		DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
			var d net.Dialer
			return d.DialContext(ctx, "unix", udsPath)
		},
		MaxIdleConns:        100,
		MaxIdleConnsPerHost: 100,
		IdleConnTimeout:     90 * time.Second,
	}

	client := &http.Client{
		Transport: transport,
		Timeout:   200 * time.Millisecond,
	}

	return &SignatureService{
		DB:      db,
		udsPath: udsPath,
		client:  client,
	}
}

// GetDevicePublicKey retrieves the public key for a specific user and device.
func (s *SignatureService) GetDevicePublicKey(ctx context.Context, userID uuid.UUID, deviceID string) (string, error) {
	cacheKey := userID.String() + ":" + deviceID
	if val, ok := s.cache.Load(cacheKey); ok {
		entry := val.(keyCacheEntry)
		if time.Now().Before(entry.expiresAt) {
			return entry.publicKey, nil
		}
	}

	var publicKey string
	err := s.DB.QueryRowContext(ctx, "SELECT public_key FROM user_device_bindings WHERE user_id = $1 AND device_id = $2 AND is_active = true", userID, deviceID).Scan(&publicKey)
	if err != nil {
		if err == sql.ErrNoRows {
			return "", fmt.Errorf("device not recognized or link revoked")
		}
		return "", fmt.Errorf("failed to fetch device public key: %w", err)
	}

	s.cache.Store(cacheKey, keyCacheEntry{
		publicKey: publicKey,
		expiresAt: time.Now().Add(5 * time.Minute),
	})

	return publicKey, nil
}

type VerifyRequest struct {
	PublicKeyB64 string `json:"public_key_b64"`
	SignatureB64 string `json:"signature_b64"`
	Message      string `json:"message"`
}

type VerifyResponse struct {
	IsValid bool    `json:"is_valid"`
	Error   *string `json:"error,omitempty"`
}

// VerifySignature delegates verification to the verify-service over Unix Domain Socket.
func (s *SignatureService) VerifySignature(ctx context.Context, publicKeyB64, signatureB64, message string) (bool, error) {
	client := s.client
	if client == nil {
		// Fallback safe path in case SignatureService was initialized directly without NewSignatureService
		transport := &http.Transport{
			DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
				var d net.Dialer
				return d.DialContext(ctx, "unix", s.udsPath)
			},
			MaxIdleConns:        100,
			MaxIdleConnsPerHost: 100,
			IdleConnTimeout:     90 * time.Second,
		}
		client = &http.Client{
			Transport: transport,
			Timeout:   200 * time.Millisecond,
		}
	}

	verifyReq := VerifyRequest{
		PublicKeyB64: publicKeyB64,
		SignatureB64: signatureB64,
		Message:      message,
	}
	reqBytes, err := json.Marshal(verifyReq)
	if err != nil {
		return false, fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", "http://localhost/verify", bytes.NewReader(reqBytes))
	if err != nil {
		return false, fmt.Errorf("failed to create http request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return false, fmt.Errorf("failed to contact verify service: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return false, fmt.Errorf("verify service returned status %d", resp.StatusCode)
	}

	var verifyResp VerifyResponse
	if err := json.NewDecoder(resp.Body).Decode(&verifyResp); err != nil {
		return false, fmt.Errorf("failed to decode verify response: %w", err)
	}

	if !verifyResp.IsValid {
		if verifyResp.Error != nil {
			return false, fmt.Errorf("verification failed: %s", *verifyResp.Error)
		}
		return false, fmt.Errorf("verification failed")
	}

	return true, nil
}

// VerifyTimestampBucket validates that the request timestamp bucket is within an acceptable time window (max 2 mins drift).
func (s *SignatureService) VerifyTimestampBucket(timestampBucketStr string) error {
	if timestampBucketStr == "" {
		return fmt.Errorf("missing timestamp bucket header")
	}
	var clientBucket int64
	if _, err := fmt.Sscanf(timestampBucketStr, "%d", &clientBucket); err != nil {
		return fmt.Errorf("invalid timestamp bucket format")
	}
	currentBucket := time.Now().Unix() / 60
	diff := currentBucket - clientBucket
	if diff < -2 || diff > 2 {
		return fmt.Errorf("signature timestamp expired or invalid replay window (drift: %d mins)", diff)
	}
	return nil
}
