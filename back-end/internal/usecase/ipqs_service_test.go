package usecase

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func withIPQSTestServer(t *testing.T, handler http.HandlerFunc) *httptest.Server {
	server := httptest.NewServer(handler)
	oldKey, oldBase := ipqsAPIKey, ipqsBaseURL
	ipqsAPIKey = "test-ipqs-key"
	ipqsBaseURL = server.URL
	t.Cleanup(func() {
		server.Close()
		ipqsAPIKey, ipqsBaseURL = oldKey, oldBase
		ClearVPNL1Cache()
	})
	return server
}

func jsonIPQSHandler(body string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(body))
	}
}

func TestIPQSService_SuspiciousCases(t *testing.T) {
	tests := []struct {
		name         string
		jsonBody     string
		isSuspicious bool
	}{
		{
			name:         "Active VPN detected",
			jsonBody:     `{"success": true, "active_vpn": true, "fraud_score": 50}`,
			isSuspicious: true,
		},
		{
			name:         "High Fraud Score (>= 90)",
			jsonBody:     `{"success": true, "active_vpn": false, "fraud_score": 92.5}`,
			isSuspicious: true,
		},
		{
			name:         "Bot Status confirmed",
			jsonBody:     `{"success": true, "bot_status": true, "fraud_score": 30}`,
			isSuspicious: true,
		},
		{
			name:         "Proxy with Fraud Score >= 75",
			jsonBody:     `{"success": true, "proxy": true, "fraud_score": 78}`,
			isSuspicious: true,
		},
		{
			name:         "Clean residential IP",
			jsonBody:     `{"success": true, "proxy": false, "active_vpn": false, "bot_status": false, "fraud_score": 15}`,
			isSuspicious: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			withIPQSTestServer(t, jsonIPQSHandler(tt.jsonBody))
			svc := NewIPQSService()
			suspicious, _, err := svc.IsSuspicious(context.Background(), "203.0.113.195", "Mozilla/5.0", "en-US")
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if suspicious != tt.isSuspicious {
				t.Errorf("expected suspicious=%v, got %v", tt.isSuspicious, suspicious)
			}
		})
	}
}

func TestIPQSService_UnsuccessfulResponse(t *testing.T) {
	withIPQSTestServer(t, jsonIPQSHandler(`{"success": false, "message": "Invalid API key"}`))
	svc := NewIPQSService()
	_, _, err := svc.IsSuspicious(context.Background(), "203.0.113.195", "", "")
	if err == nil {
		t.Fatalf("expected error for unsuccessful response, got nil")
	}
}

func TestIPQSService_UnsetAPIKey(t *testing.T) {
	oldKey := ipqsAPIKey
	ipqsAPIKey = ""
	defer func() { ipqsAPIKey = oldKey }()

	svc := NewIPQSService()
	_, _, err := svc.IsSuspicious(context.Background(), "203.0.113.195", "", "")
	if err == nil {
		t.Fatalf("expected error when IPQUALITYSCORE_API_KEY is unset")
	}
}

func TestIPQSService_ScoreTransactionRisk(t *testing.T) {
	withIPQSTestServer(t, jsonIPQSHandler(`{
		"success": true,
		"fraud_score": 10,
		"transaction_details": {
			"risk_score": 15,
			"recommended_action": "approve"
		}
	}`))

	svc := NewIPQSService()
	resp, err := svc.ScoreTransactionRisk(context.Background(), &TransactionScoreParams{
		IP:             "203.0.113.195",
		BillingEmail:   "user@example.com",
		BillingPhone:   "0812345678",
		OrderAmount:    1500.00,
		BillingCountry: "TH",
	})

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil || resp.TransactionDetails == nil {
		t.Fatalf("expected transaction_details in response")
	}
	if resp.TransactionDetails.RecommendedAction != "approve" {
		t.Errorf("expected recommended_action='approve', got '%s'", resp.TransactionDetails.RecommendedAction)
	}
}
