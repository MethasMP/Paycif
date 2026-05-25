package service

import (
	"context"
	"database/sql"
	"encoding/base64"
	"fmt"
	"time"

	"github.com/google/uuid"

	pb "paysif/internal/grpc/pb" // Correct import path based on go_package option
)

// SignatureService handles Ed25519 signature verification via High-Performance Rust Microservice.
type SignatureService struct {
	grpcClient pb.FXServiceClient
	DB         *sql.DB
}

// NewSignatureService creates a new SignatureService injecting dependencies.
func NewSignatureService(client pb.FXServiceClient, db *sql.DB) *SignatureService {
	return &SignatureService{
		grpcClient: client,
		DB:         db,
	}
}

// GetDevicePublicKey retrieves the public key for a specific user and device.
func (s *SignatureService) GetDevicePublicKey(ctx context.Context, userID uuid.UUID, deviceID string) (string, error) {
	var publicKey string
	err := s.DB.QueryRowContext(ctx, "SELECT public_key FROM user_device_bindings WHERE user_id = $1 AND device_id = $2 AND is_active = true", userID, deviceID).Scan(&publicKey)
	if err != nil {
		if err == sql.ErrNoRows {
			return "", fmt.Errorf("device not recognized or link revoked")
		}
		return "", fmt.Errorf("failed to fetch device public key: %w", err)
	}
	return publicKey, nil
}

// VerifySignature delegates verification to the high-performance Rust service.
// publicKey and signature are expected to be base64 encoded strings.
func (s *SignatureService) VerifySignature(ctx context.Context, publicKeyB64, signatureB64, message string) (bool, error) {
	// 1. Decode Base64 Inputs
	pubKeyBytes, err := base64.StdEncoding.DecodeString(publicKeyB64)
	if err != nil {
		return false, fmt.Errorf("invalid public key encoding: %w", err)
	}

	sigBytes, err := base64.StdEncoding.DecodeString(signatureB64)
	if err != nil {
		return false, fmt.Errorf("invalid signature encoding: %w", err)
	}

	// 2. Call Rust via gRPC (over UDS/TCP)
	if s.grpcClient == nil {
		return false, fmt.Errorf("signature verification unavailable: rust engine is offline")
	}

	rpcCtx, cancel := context.WithTimeout(ctx, 2*time.Second) // Fast timeout for auth
	defer cancel()

	resp, err := s.grpcClient.VerifySignature(rpcCtx, &pb.VerifySignatureRequest{
		PublicKey: pubKeyBytes,
		Signature: sigBytes,
		Message:   []byte(message),
	})

	if err != nil {
		// Log error but don't leak details to caller for security
		return false, fmt.Errorf("rust signature verification error: %w", err)
	}

	if !resp.Valid {
		return false, fmt.Errorf("verification failed: %s", resp.ErrorMessage)
	}

	return true, nil
}
