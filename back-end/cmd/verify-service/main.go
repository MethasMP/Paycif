package main

import (
	"crypto/ed25519"
	"encoding/base64"
	"net"
	"net/http"
	"os"
	"unsafe"

	"github.com/gin-gonic/gin"
)

type VerifyRequest struct {
	PublicKeyB64 string `json:"public_key_b64" binding:"required"`
	SignatureB64 string `json:"signature_b64" binding:"required"`
	Message      string `json:"message" binding:"required"`
}

type VerifyResponse struct {
	IsValid bool    `json:"is_valid"`
	Error   *string `json:"error,omitempty"`
}

func verifyHandler(c *gin.Context) {
	var payload VerifyRequest
	if err := c.ShouldBindJSON(&payload); err != nil {
		errStr := err.Error()
		c.JSON(http.StatusBadRequest, VerifyResponse{
			IsValid: false,
			Error:   &errStr,
		})
		return
	}

	var pubKeyBytes [32]byte
	nPub, err := base64.StdEncoding.Decode(pubKeyBytes[:], unsafe.Slice(unsafe.StringData(payload.PublicKeyB64), len(payload.PublicKeyB64)))
	if err != nil || nPub != ed25519.PublicKeySize {
		errStr := "Invalid public key size/format"
		c.JSON(http.StatusBadRequest, VerifyResponse{IsValid: false, Error: &errStr})
		return
	}

	var sigBytes [64]byte
	nSig, err := base64.StdEncoding.Decode(sigBytes[:], unsafe.Slice(unsafe.StringData(payload.SignatureB64), len(payload.SignatureB64)))
	if err != nil || nSig != ed25519.SignatureSize {
		errStr := "Invalid signature size/format"
		c.JSON(http.StatusBadRequest, VerifyResponse{IsValid: false, Error: &errStr})
		return
	}

	msgBytes := unsafe.Slice(unsafe.StringData(payload.Message), len(payload.Message))
	isValid := ed25519.Verify(pubKeyBytes[:], msgBytes, sigBytes[:])

	c.JSON(http.StatusOK, VerifyResponse{
		IsValid: isValid,
	})
}

func main() {
	// Set gin mode from environment
	if os.Getenv("GIN_MODE") == "" {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.New()
	r.Use(gin.Recovery())

	// Add simple logger if not in release mode
	if gin.Mode() != gin.ReleaseMode {
		r.Use(gin.Logger())
	}

	r.POST("/verify", verifyHandler)

	var listener net.Listener
	var err error
	udsPath := os.Getenv("VERIFY_SERVICE_UDS")
	if udsPath == "" {
		udsPath = "/tmp/verify_service.sock"
	}

	if os.Getenv("VERIFY_SERVICE_TCP_ONLY") == "true" {
		port := os.Getenv("VERIFY_SERVICE_PORT")
		if port == "" {
			port = "3001"
		}
		listener, err = net.Listen("tcp", "0.0.0.0:"+port)
		if err != nil {
			panic(err)
		}
		println("🚀 Go Verify Service running on http://0.0.0.0:" + port)
	} else {
		_ = os.Remove(udsPath)
		listener, err = net.Listen("unix", udsPath)
		if err != nil {
			panic(err)
		}
		_ = os.Chmod(udsPath, 0777)
		println("⚡ Go Verify Service running on UDS socket: " + udsPath)
	}

	if err := http.Serve(listener, r); err != nil {
		panic(err)
	}
}
