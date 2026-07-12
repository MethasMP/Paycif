package middleware

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"paysif/internal/usecase"

	"github.com/gin-gonic/gin"
)

func newTestCloudflareIPService(t *testing.T, seedV4CIDR string) *usecase.CloudflareIPRangeService {
	t.Helper()
	v4 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(seedV4CIDR + "\n"))
	}))
	t.Cleanup(v4.Close)
	v6 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("2001:db8::/32\n"))
	}))
	t.Cleanup(v6.Close)

	// cloudflareIPv4URL/cloudflareIPv6URL are package-level vars resolved
	// once from env at package init, so tests override them directly
	// (matching geo_block_service_test.go's ipapiBaseURL override pattern)
	// rather than via os.Setenv, which would have no effect after init.
	oldV4, oldV6 := usecase.SetCloudflareIPURLsForTest(v4.URL, v6.URL)
	t.Cleanup(func() { usecase.SetCloudflareIPURLsForTest(oldV4, oldV6) })

	svc := usecase.NewCloudflareIPRangeService()
	if err := svc.Refresh(context.Background()); err != nil {
		t.Fatalf("failed to seed test service: %v", err)
	}
	return svc
}

func newTestRouter(svc *usecase.CloudflareIPRangeService) *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	// nil SecurityEventService is a valid no-op — these tests exercise
	// allow/reject behavior, not event persistence.
	r.Use(CloudflareBypassMiddleware(svc, nil))
	r.GET("/x", func(c *gin.Context) { c.Status(http.StatusOK) })
	return r
}

func TestCloudflareBypassMiddleware_RejectsNonCloudflareFlyClientIP(t *testing.T) {
	svc := newTestCloudflareIPService(t, "9.9.9.0/24")
	r := newTestRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/x", nil)
	req.Header.Set("Fly-Client-IP", "1.2.3.4") // outside the seeded range
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusForbidden {
		t.Fatalf("got status %d, want 403", w.Code)
	}
	var body map[string]string
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to decode response body: %v", err)
	}
	if body["error"] != "service_unavailable_in_region" {
		t.Errorf("got error %q, want service_unavailable_in_region", body["error"])
	}
}

func TestCloudflareBypassMiddleware_AllowsRealCloudflareFlyClientIP(t *testing.T) {
	svc := newTestCloudflareIPService(t, "1.2.3.0/24")
	r := newTestRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/x", nil)
	req.Header.Set("Fly-Client-IP", "1.2.3.4") // inside the seeded range
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("got status %d, want 200", w.Code)
	}
}

func TestCloudflareBypassMiddleware_MissingHeaderRejectedByDefault(t *testing.T) {
	svc := newTestCloudflareIPService(t, "1.2.3.0/24")
	r := newTestRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/x", nil)
	req.RemoteAddr = "203.0.113.9:12345" // not local, no Fly-Client-IP header
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusForbidden {
		t.Fatalf("got status %d, want 403 when Fly-Client-IP is missing and request isn't local", w.Code)
	}
}

func TestCloudflareBypassMiddleware_MissingHeaderAllowedForLocalDev(t *testing.T) {
	svc := newTestCloudflareIPService(t, "1.2.3.0/24")
	r := newTestRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/x", nil)
	req.RemoteAddr = "127.0.0.1:12345"
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("got status %d, want 200 for local dev with no Fly-Client-IP", w.Code)
	}
}

func TestCloudflareBypassMiddleware_MissingHeaderAllowedByEscapeHatch(t *testing.T) {
	svc := newTestCloudflareIPService(t, "1.2.3.0/24")
	r := newTestRouter(svc)

	oldVal := os.Getenv("DISABLE_CLOUDFLARE_BYPASS_CHECK")
	os.Setenv("DISABLE_CLOUDFLARE_BYPASS_CHECK", "true")
	defer os.Setenv("DISABLE_CLOUDFLARE_BYPASS_CHECK", oldVal)

	req := httptest.NewRequest(http.MethodGet, "/x", nil)
	req.RemoteAddr = "203.0.113.9:12345" // not local, but escape hatch is on
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("got status %d, want 200 when DISABLE_CLOUDFLARE_BYPASS_CHECK=true", w.Code)
	}
}
