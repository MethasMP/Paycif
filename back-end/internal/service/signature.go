package service

import (
	"crypto/ed25519"
	"encoding/base64"
	"errors"
	"fmt"
)

// SignatureService handles Ed25519 signature verification.
type SignatureService struct{}

// NewSignatureService creates a new SignatureService.
func NewSignatureService() *SignatureService {
	return &SignatureService{}
}

// VerifySignature verifies an Ed25519 signature for a given message and public key.
// publicKey and signature are expected to be base64 encoded strings.
func (s *SignatureService) VerifySignature(publicKeyB64, signatureB64, message string) (bool, error) {
	pub, err := base64.StdEncoding.DecodeString(publicKeyB64)
	if err != nil {
		return false, fmt.Errorf("failed to decode public key: %w", err)
	}

	sig, err := base64.StdEncoding.DecodeString(signatureB64)
	if err != nil {
		return false, fmt.Errorf("failed to decode signature: %w", err)
	}

	if len(pub) != ed25519.PublicKeySize {
		return false, errors.New("invalid public key size")
	}

	if len(sig) != ed25519.SignatureSize {
		return false, errors.New("invalid signature size")
	}

	isValid := ed25519.Verify(pub, []byte(message), sig)
	return isValid, nil
}
