package service

import (
	"context"
	"encoding/base64"
	"fmt"
	"time"

	pb "paysif/internal/grpc/pb" // Correct import path based on go_package option
)

// SignatureService handles Ed25519 signature verification via High-Performance Rust Microservice.
type SignatureService struct {
	grpcClient pb.FXServiceClient
}

// NewSignatureService creates a new SignatureService injecting the Rust gRPC client.
func NewSignatureService(client pb.FXServiceClient) *SignatureService {
	return &SignatureService{
		grpcClient: client,
	}
}

// VerifySignature delegates verification to the high-performance Rust service.
// publicKey and signature are expected to be base64 encoded strings.
func (s *SignatureService) VerifySignature(publicKeyB64, signatureB64, message string) (bool, error) {
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

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second) // Fast timeout for auth
	defer cancel()

	resp, err := s.grpcClient.VerifySignature(ctx, &pb.VerifySignatureRequest{
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
