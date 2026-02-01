package service

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"os"
)

// CryptoService handles encryption and decryption.
type CryptoService struct {
	key []byte
}

// NewCryptoService creates a new CryptoService.
func NewCryptoService() *CryptoService {
	keyStr := os.Getenv("ENCRYPTION_KEY")
	if keyStr == "" {
		// 🚨 CRITICAL SECURITY GUARDRAIL
		// In a Fintech environment, we MUST NOT start if the encryption key is missing.
		// Using a fallback is dangerous as it might lead to data being encrypted with a known key.
		panic("FATAL: ENCRYPTION_KEY environment variable is not set. System cannot start in a secure state.")
	}

	key := []byte(keyStr)
	if len(key) != 32 {
		panic(fmt.Sprintf("FATAL: ENCRYPTION_KEY must be exactly 32 bytes for AES-256 (current length: %d)", len(key)))
	}

	return &CryptoService{key: key}
}

// Encrypt encrypts plain text string into base64 encoded ciphertext.
func (s *CryptoService) Encrypt(plaintext string) (string, error) {
	block, err := aes.NewCipher(s.key)
	if err != nil {
		return "", err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonce := make([]byte, gcm.NonceSize())
	if _, err = io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}

	ciphertext := gcm.Seal(nonce, nonce, []byte(plaintext), nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// Decrypt decrypts base64 encoded ciphertext back to plain text string.
func (s *CryptoService) Decrypt(cryptoText string) (string, error) {
	data, err := base64.StdEncoding.DecodeString(cryptoText)
	if err != nil {
		return "", err
	}

	block, err := aes.NewCipher(s.key)
	if err != nil {
		return "", err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonceSize := gcm.NonceSize()
	if len(data) < nonceSize {
		return "", errors.New("ciphertext too short")
	}

	nonce, ciphertext := data[:nonceSize], data[nonceSize:]
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", err
	}

	return string(plaintext), nil
}
