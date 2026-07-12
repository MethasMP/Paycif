package usecase

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

func withIPQSTestServer(t *testing.T, handler http.HandlerFunc) *httptest.Server {
	t.Helper()
	server := httptest.NewServer(handler)
	oldKey, oldBase := ipqsAPIKey, ipqsBaseURL
	ipqsAPIKey = "test-key"
	ipqsBaseURL = server.URL
	t.Cleanup(func() {
		server.Close()
		ipqsAPIKey, ipqsBaseURL = oldKey, oldBase
	})
	return server
}

func jsonIPQSHandler(body string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(body))
	}
}

func TestVPNDetection_ProxyTrueIsSuspicious(t *testing.T) {
	withIPQSTestServer(t, jsonIPQSHandler(`{"success":true,"proxy":true,"vpn":false,"tor":false,"fraud_score":10}`))

	svc := NewVPNDetectionService()
	suspicious, err := svc.IsSuspicious(context.Background(), "1.2.3.4")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !suspicious {
		t.Errorf("expected proxy=true to be flagged suspicious")
	}
}

func TestVPNDetection_VPNTrueIsSuspicious(t *testing.T) {
	withIPQSTestServer(t, jsonIPQSHandler(`{"success":true,"proxy":false,"vpn":true,"tor":false,"fraud_score":10}`))

	svc := NewVPNDetectionService()
	suspicious, err := svc.IsSuspicious(context.Background(), "1.2.3.4")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !suspicious {
		t.Errorf("expected vpn=true to be flagged suspicious")
	}
}

func TestVPNDetection_TorTrueIsSuspicious(t *testing.T) {
	withIPQSTestServer(t, jsonIPQSHandler(`{"success":true,"proxy":false,"vpn":false,"tor":true,"fraud_score":10}`))

	svc := NewVPNDetectionService()
	suspicious, err := svc.IsSuspicious(context.Background(), "1.2.3.4")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !suspicious {
		t.Errorf("expected tor=true to be flagged suspicious")
	}
}

func TestVPNDetection_HighFraudScoreIsSuspicious(t *testing.T) {
	withIPQSTestServer(t, jsonIPQSHandler(`{"success":true,"proxy":false,"vpn":false,"tor":false,"fraud_score":95}`))

	svc := NewVPNDetectionService()
	suspicious, err := svc.IsSuspicious(context.Background(), "1.2.3.4")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !suspicious {
		t.Errorf("expected fraud_score=95 (above default threshold 85) to be flagged suspicious")
	}
}

func TestVPNDetection_CleanIPIsNotSuspicious(t *testing.T) {
	withIPQSTestServer(t, jsonIPQSHandler(`{"success":true,"proxy":false,"vpn":false,"tor":false,"fraud_score":5}`))

	svc := NewVPNDetectionService()
	suspicious, err := svc.IsSuspicious(context.Background(), "1.2.3.4")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if suspicious {
		t.Errorf("expected a clean IP not to be flagged suspicious")
	}
}

func TestVPNDetection_FraudScoreThresholdIsTunable(t *testing.T) {
	withIPQSTestServer(t, jsonIPQSHandler(`{"success":true,"proxy":false,"vpn":false,"tor":false,"fraud_score":50}`))

	oldThreshold := ipqsFraudScoreThreshold
	ipqsFraudScoreThreshold = 40
	defer func() { ipqsFraudScoreThreshold = oldThreshold }()

	svc := NewVPNDetectionService()
	suspicious, err := svc.IsSuspicious(context.Background(), "1.2.3.4")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !suspicious {
		t.Errorf("expected fraud_score=50 to be suspicious once threshold is lowered to 40")
	}
}

func TestVPNDetection_FailsOpenOnAPIError(t *testing.T) {
	withIPQSTestServer(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	})

	svc := NewVPNDetectionService()
	_, err := svc.IsSuspicious(context.Background(), "1.2.3.4")
	if err == nil {
		t.Fatalf("expected an error on API failure (caller is responsible for failing open)")
	}
	var quotaErr quotaExceededError
	if errors.As(err, &quotaErr) {
		t.Errorf("expected a generic failure, not a quota-exceeded error, for a plain 500")
	}
}

func TestVPNDetection_QuotaExceededIsDistinguishable(t *testing.T) {
	withIPQSTestServer(t, jsonIPQSHandler(`{"success":false,"message":"You have exceeded your request quota."}`))

	svc := NewVPNDetectionService()
	_, err := svc.IsSuspicious(context.Background(), "1.2.3.4")
	if err == nil {
		t.Fatalf("expected an error when the API reports quota exceeded")
	}
	var quotaErr quotaExceededError
	if !errors.As(err, &quotaErr) {
		t.Errorf("expected a quotaExceededError, got %T: %v", err, err)
	}
}

func TestVPNDetection_MissingAPIKeyFailsOpen(t *testing.T) {
	server := httptest.NewServer(func() http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			t.Errorf("should not call IPQS at all when no API key is configured")
		}
	}())
	defer server.Close()

	oldKey, oldBase := ipqsAPIKey, ipqsBaseURL
	ipqsAPIKey = ""
	ipqsBaseURL = server.URL
	defer func() { ipqsAPIKey, ipqsBaseURL = oldKey, oldBase }()

	svc := NewVPNDetectionService()
	_, err := svc.IsSuspicious(context.Background(), "1.2.3.4")
	if err == nil {
		t.Fatalf("expected an error when IPQS_API_KEY is unset")
	}
}
