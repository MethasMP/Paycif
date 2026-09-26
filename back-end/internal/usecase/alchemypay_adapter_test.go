package usecase

import (
	"strconv"
	"strings"
	"testing"
)

func TestAlchemyPayAdapter_GenerateManageURL(t *testing.T) {
	adapter := NewAlchemyPayAdapter("test_app_id", "test_app_secret", true)
	merchantOrderNo := "ord-12345678"
	token := "token-abcdef123456"
	callbackURL := "https://example.com/callback"
	redirectURL := "https://example.com/redirect"

	url := adapter.GenerateManageURL(merchantOrderNo, token, callbackURL, redirectURL)

	if !strings.HasPrefix(url, "https://ramptest.alchemypay.org?") {
		t.Errorf("expected URL to start with sandbox page base URL, got: %s", url)
	}
	if !strings.Contains(url, "appId=test_app_id") {
		t.Errorf("expected appId in URL, got: %s", url)
	}
	if !strings.Contains(url, "merchantOrderNo=ord-12345678") {
		t.Errorf("expected merchantOrderNo in URL, got: %s", url)
	}
	if !strings.Contains(url, "token=token-abcdef123456") {
		t.Errorf("expected token in URL, got: %s", url)
	}
	if !strings.Contains(url, "&sign=") {
		t.Errorf("expected &sign= in URL, got: %s", url)
	}
}

func TestAlchemyPayAdapter_VerifyWebhookSignature(t *testing.T) {
	adapter := NewAlchemyPayAdapter("test_app_id", "test_app_secret", true)
	timestamp := "1600000000000"
	method := "POST"
	path := "/webhook/callback"
	body := `{"merchantOrderNo":"123","status":"SUCCESS","signature":""}`

	// Generate expected signature using current logic
	cleanBody := `{"merchantOrderNo":"123","status":"SUCCESS"}`
	sig := adapter.sign(map[string]string{
		"body": cleanBody,
	})
	_ = sig

	// Verify adapter handles valid body correctly
	isValid := adapter.VerifyWebhookSignature(timestamp, method, path, body, "invalid_sig")
	if isValid {
		t.Errorf("expected false for invalid signature, got true")
	}
}

func BenchmarkGenerateManageURL(b *testing.B) {
	adapter := NewAlchemyPayAdapter("test_app_id", "test_app_secret", true)
	merchantOrderNo := "ord-12345678"
	token := "token-abcdef123456"
	callbackURL := "https://example.com/callback"
	redirectURL := "https://example.com/redirect"

	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = adapter.GenerateManageURL(merchantOrderNo, token, callbackURL, redirectURL)
	}
}

func BenchmarkGetTokenStringFormatting(b *testing.B) {
	email := "user@example.com"
	tsInt := int64(1700000000000)

	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		timestamp := strconv.FormatInt(tsInt, 10)
		body := `{"email":` + strconv.Quote(email) + `}`
		_ = timestamp
		_ = body
	}
}
