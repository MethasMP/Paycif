package main

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"net/http"
	"net/http/httptest"
	"testing"

	"paysif/internal/usecase"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

func TestHandleOnRampKycWebhook_SignatureVerification(t *testing.T) {
	gin.SetMode(gin.TestMode)

	t.Run("no secret configured, bypass signature check", func(t *testing.T) {
		handler := &KYCHandler{Service: nil}
		r := gin.New()
		r.POST("/kyc/onramp-webhook", handler.HandleOnRampKycWebhook)

		body := []byte(`{"userNo":"ach_user_123","merchantNo":"m_01","kycStatus":1}`) // missing email
		req := httptest.NewRequest(http.MethodPost, "/kyc/onramp-webhook", bytes.NewReader(body))
		w := httptest.NewRecorder()

		r.ServeHTTP(w, req)

		// Expecting Bad Request (400) because email is missing, but it bypassed signature check
		assert.Equal(t, http.StatusBadRequest, w.Code)
		assert.Contains(t, w.Body.String(), "Missing email in webhook payload")
	})

	t.Run("secret configured, missing signature", func(t *testing.T) {
		client := usecase.NewAlchemyPayKYCClient("appKey", "secretKey", "merchantNo", true)
		handler := &KYCHandler{
			Service: &usecase.KYCService{
				KYCClient: client,
			},
		}
		r := gin.New()
		r.POST("/kyc/onramp-webhook", handler.HandleOnRampKycWebhook)

		body := []byte(`{"userNo":"ach_user_123","email":"test@example.com","kycStatus":1}`)
		req := httptest.NewRequest(http.MethodPost, "/kyc/onramp-webhook", bytes.NewReader(body))
		w := httptest.NewRecorder()

		r.ServeHTTP(w, req)

		// Expecting StatusUnauthorized (401) because signature is missing/invalid when AppKey is set
		assert.Equal(t, http.StatusUnauthorized, w.Code)
		assert.Contains(t, w.Body.String(), "Invalid signature")
	})

	t.Run("secret configured, invalid signature", func(t *testing.T) {
		client := usecase.NewAlchemyPayKYCClient("appKey", "secretKey", "merchantNo", true)
		handler := &KYCHandler{
			Service: &usecase.KYCService{
				KYCClient: client,
			},
		}
		r := gin.New()
		r.POST("/kyc/onramp-webhook", handler.HandleOnRampKycWebhook)

		body := []byte(`{"userNo":"ach_user_123","email":"test@example.com","kycStatus":1}`)
		req := httptest.NewRequest(http.MethodPost, "/kyc/onramp-webhook", bytes.NewReader(body))
		req.Header.Set("ach-access-timestamp", "1234567890")
		req.Header.Set("ach-access-sign", "wrongsignature")
		w := httptest.NewRecorder()

		r.ServeHTTP(w, req)

		// Expecting StatusUnauthorized (401) because signature is invalid
		assert.Equal(t, http.StatusUnauthorized, w.Code)
		assert.Contains(t, w.Body.String(), "Invalid signature")
	})

	t.Run("secret configured, valid signature", func(t *testing.T) {
		client := usecase.NewAlchemyPayKYCClient("appKey", "secretKey", "merchantNo", true)
		handler := &KYCHandler{
			Service: &usecase.KYCService{
				KYCClient: client,
			},
		}
		r := gin.New()
		r.POST("/kyc/onramp-webhook", handler.HandleOnRampKycWebhook)

		body := []byte(`{"userNo":"ach_user_123","email":"test@example.com","kycStatus":1}`)
		ts := "1234567890"

		// Use the correct message format for signing: timestamp + method + path + body
		msg := ts + "POST" + "/api/v1/kyc/onramp-webhook" + string(body)
		mac := hmac.New(sha256.New, []byte("secretKey"))
		mac.Write([]byte(msg))
		validSig := base64.StdEncoding.EncodeToString(mac.Sum(nil))

		req := httptest.NewRequest(http.MethodPost, "/kyc/onramp-webhook", bytes.NewReader(body))
		req.Header.Set("ach-access-timestamp", ts)
		req.Header.Set("ach-access-sign", validSig)
		w := httptest.NewRecorder()

		r.ServeHTTP(w, req)

		// Since s.DB is nil, SyncOnRampKycStatus will bypass the database sync and return nil (no error).
		// Thus, we expect HTTP 200 OK and status "ok".
		assert.Equal(t, http.StatusOK, w.Code)
		assert.Contains(t, w.Body.String(), "ok")
	})
}
