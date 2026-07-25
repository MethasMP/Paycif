package usecase

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"
)

func TestIsAllowedAndGPS(t *testing.T) {
	svc := NewGeoBlockService()

	allowed := []string{"TH", "th"}
	for _, c := range allowed {
		if !svc.IsAllowed(c) {
			t.Errorf("expected %s to be allowed", c)
		}
	}

	blocked := []string{"US", "GB", "DE", "SG", "JP", "AU", "", "FR"}
	for _, c := range blocked {
		if svc.IsAllowed(c) {
			t.Errorf("expected %s to be blocked (not allowed)", c)
		}
	}

	// GPS checks
	inTH := []struct{ lat, lng float64 }{
		{13.7367, 100.5231}, // Bangkok
		{18.7883, 98.9853},  // Chiang Mai
		{7.8804, 98.3922},   // Phuket
	}
	for _, pt := range inTH {
		if !svc.IsInThailandGPS(pt.lat, pt.lng) {
			t.Errorf("expected lat=%f, lng=%f to be in Thailand", pt.lat, pt.lng)
		}
	}

	outTH := []struct{ lat, lng float64 }{
		{37.7749, -122.4194}, // San Francisco
		{51.5074, -0.1278},   // London
		{1.3521, 103.8198},   // Singapore
	}
	for _, pt := range outTH {
		if svc.IsInThailandGPS(pt.lat, pt.lng) {
			t.Errorf("expected lat=%f, lng=%f to be outside Thailand", pt.lat, pt.lng)
		}
	}
}

func TestTruncateIP(t *testing.T) {
	cases := map[string]string{
		"203.0.113.42":                 "203.0.113.0",
		"8.8.8.8":                      "8.8.8.0",
		"not-an-ip":                    "invalid",
		"2001:db8:85a3::8a2e:370:7334": "2001:db8:85a3::",
	}
	for in, want := range cases {
		if got := TruncateIP(in); got != want {
			t.Errorf("TruncateIP(%q) = %q, want %q", in, got, want)
		}
	}
}

func init() {
	DisableRedisCacheForTesting = true
}

func TestResolveCountry_PrimaryProviderUsed(t *testing.T) {
	ClearGeoL1Cache()
	primary := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("US"))
	}))
	defer primary.Close()

	oldPrimary := ipapiBaseURL
	ipapiBaseURL = primary.URL
	defer func() { ipapiBaseURL = oldPrimary }()

	svc := NewGeoBlockService()
	country, err := svc.ResolveCountry(context.Background(), "1.2.3.4")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if country != "US" {
		t.Errorf("got country %q, want US", country)
	}
	if svc.IsAllowed(country) {
		t.Errorf("expected US to not be allowed")
	}
}

func TestResolveCountry_FallsBackToSecondaryProvider(t *testing.T) {
	ClearGeoL1Cache()
	primary := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer primary.Close()

	fallback := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"success":true,"country_code":"TH"}`))
	}))
	defer fallback.Close()

	oldPrimary, oldFallback := ipapiBaseURL, ipwhoisBaseURL
	ipapiBaseURL = primary.URL
	ipwhoisBaseURL = fallback.URL
	defer func() { ipapiBaseURL, ipwhoisBaseURL = oldPrimary, oldFallback }()

	svc := NewGeoBlockService()
	country, err := svc.ResolveCountry(context.Background(), "1.2.3.4")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if country != "TH" {
		t.Errorf("got country %q, want TH (from fallback provider)", country)
	}
	if !svc.IsAllowed(country) {
		t.Errorf("expected TH to be allowed")
	}
}

func TestResolveCountry_FailsOpenWhenBothProvidersDown(t *testing.T) {
	ClearGeoL1Cache()
	primary := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer primary.Close()

	fallback := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer fallback.Close()

	oldPrimary, oldFallback := ipapiBaseURL, ipwhoisBaseURL
	ipapiBaseURL = primary.URL
	ipwhoisBaseURL = fallback.URL
	defer func() { ipapiBaseURL, ipwhoisBaseURL = oldPrimary, oldFallback }()

	svc := NewGeoBlockService()
	_, err := svc.ResolveCountry(context.Background(), "1.2.3.4")
	if err == nil {
		t.Fatalf("expected an error when both providers are down (caller is responsible for failing open)")
	}
}

func TestSendFailoverAlertEmail_NoAPIKeySkipsSend(t *testing.T) {
	called := false
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
	}))
	defer server.Close()

	oldKey, oldBase := resendAPIKey, resendBaseURL
	resendAPIKey = ""
	resendBaseURL = server.URL
	defer func() { resendAPIKey, resendBaseURL = oldKey, oldBase }()

	sendFailoverAlertEmail("Country geo-fencing", 3)

	if called {
		t.Errorf("expected no HTTP call to Resend when RESEND_API_KEY is unset")
	}
}

func TestSendFailoverAlertEmail_SendsExpectedRequest(t *testing.T) {
	var gotAuth, gotMethod string
	var gotBody map[string]interface{}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
		gotMethod = r.Method
		_ = json.NewDecoder(r.Body).Decode(&gotBody)
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	oldKey, oldBase, oldTo, oldFrom := resendAPIKey, resendBaseURL, alertToEmail, alertFromEmail
	resendAPIKey = "test-key"
	resendBaseURL = server.URL
	alertToEmail = "founder@example.com"
	alertFromEmail = "alerts@example.com"
	defer func() {
		resendAPIKey, resendBaseURL, alertToEmail, alertFromEmail = oldKey, oldBase, oldTo, oldFrom
	}()

	sendFailoverAlertEmail("Country geo-fencing", 5)

	if gotMethod != http.MethodPost {
		t.Errorf("got method %q, want POST", gotMethod)
	}
	if gotAuth != "Bearer test-key" {
		t.Errorf("got Authorization %q, want 'Bearer test-key'", gotAuth)
	}
	if gotBody["from"] != "alerts@example.com" {
		t.Errorf("got from %v, want alerts@example.com", gotBody["from"])
	}
	to, _ := gotBody["to"].([]interface{})
	if len(to) != 1 || to[0] != "founder@example.com" {
		t.Errorf("got to %v, want [founder@example.com]", gotBody["to"])
	}
}

func TestMaybeSendFailoverAlert_CooldownSuppressesRepeatSends(t *testing.T) {
	callCount := int32(0)
	received := make(chan struct{}, 2)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&callCount, 1)
		w.WriteHeader(http.StatusOK)
		received <- struct{}{}
	}))
	defer server.Close()

	oldKey, oldBase := resendAPIKey, resendBaseURL
	resendAPIKey = "test-key"
	resendBaseURL = server.URL
	oldLastAlert := atomic.SwapInt64(&lastAlertUnix, 0)
	defer func() {
		resendAPIKey, resendBaseURL = oldKey, oldBase
		atomic.StoreInt64(&lastAlertUnix, oldLastAlert)
	}()

	maybeSendFailoverAlert("Country geo-fencing", 3)
	select {
	case <-received:
	case <-time.After(2 * time.Second):
		t.Fatalf("expected first alert to fire, timed out waiting for HTTP call")
	}

	// Immediately fire again — should be suppressed by the cooldown.
	maybeSendFailoverAlert("Country geo-fencing", 4)
	select {
	case <-received:
		t.Fatalf("expected second alert to be suppressed by cooldown, but got another HTTP call")
	case <-time.After(300 * time.Millisecond):
	}

	if got := atomic.LoadInt32(&callCount); got != 1 {
		t.Errorf("got %d Resend calls, want exactly 1 (cooldown should suppress the second)", got)
	}
}

func TestIsLocalIP(t *testing.T) {
	local := []string{"", "127.0.0.1", "::1"}
	for _, ip := range local {
		if !IsLocalIP(ip) {
			t.Errorf("expected %q to be treated as local", ip)
		}
	}
	if IsLocalIP("8.8.8.8") {
		t.Errorf("expected 8.8.8.8 not to be treated as local")
	}
}
