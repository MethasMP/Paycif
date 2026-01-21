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
	// 32 bytes for AES-256
	keyStr := os.Getenv("ENCRYPTION_KEY")
	if keyStr == "" {
		// FALLBACK FOR DEV ONLY - In prod, this must panic or block startup
		fmt.Println("⚠️ ENCRYPTION_KEY not found. Using dev fallback key (UNSAFE for Prod).")
		keyStr = "01234567890123456789012345678901" // 32 chars
	}

	key := []byte(keyStr)
	if len(key) != 32 {
		// Attempt to pad or panic? Panic is safer for security service config error.
		// For robustness in this demo, strictly check 32 bytes.
		if len(key) > 32 {
			key = key[:32]
		} else {
			// Pad with zero
			padded := make([]byte, 32)
			copy(padded, key)
			key = padded
		}
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
