package usecase

import (
	"fmt"
	"strconv"
	"strings"
	"testing"
	"time"
)

func TestAlchemyPayAdapter_GenerateManageURL(t *testing.T) {
	adapter := NewAlchemyPayAdapter("test-app-id", "test-app-secret", true)
	url := adapter.GenerateManageURL("order-123", "token-abc", "https://example.com/callback", "https://example.com/redirect")

	if !strings.HasPrefix(url, achPageSandboxURL) {
		t.Errorf("expected URL to start with %s, got %s", achPageSandboxURL, url)
	}
	if !strings.Contains(url, "merchantOrderNo=order-123") {
		t.Errorf("expected URL to contain merchantOrderNo=order-123, got %s", url)
	}
	if !strings.Contains(url, "&sign=") {
		t.Errorf("expected URL to contain &sign=, got %s", url)
	}
}

func BenchmarkGenerateManageURL_Sprintf(b *testing.B) {
	adapter := NewAlchemyPayAdapter("test-app-id", "test-app-secret", true)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		ts := fmt.Sprintf("%d", time.Now().UnixMilli())
		queryString := "appId=test-app-id&crypto=USDC&merchantOrderNo=order-123&network=BASE&showTable=buy&timestamp=" + ts
		sig := "mockSig"
		_ = fmt.Sprintf("%s?%s&sign=%s", adapter.pageBaseURL, queryString, sig)
	}
}

func BenchmarkGenerateManageURL_Concat(b *testing.B) {
	adapter := NewAlchemyPayAdapter("test-app-id", "test-app-secret", true)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		ts := strconv.FormatInt(time.Now().UnixMilli(), 10)
		queryString := "appId=test-app-id&crypto=USDC&merchantOrderNo=order-123&network=BASE&showTable=buy&timestamp=" + ts
		sig := "mockSig"
		_ = adapter.pageBaseURL + "?" + queryString + "&sign=" + sig
	}
}
