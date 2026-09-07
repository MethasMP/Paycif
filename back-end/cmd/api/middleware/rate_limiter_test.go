package middleware

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

func TestRateLimiterMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	// 1. Initial request under limit
	req := httptest.NewRequest("GET", "/test", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	// 2. Bypass header in test mode
	reqBypass := httptest.NewRequest("GET", "/test", nil)
	reqBypass.Header.Set("X-Load-Test-User-Id", "user-123")
	wBypass := httptest.NewRecorder()
	r.ServeHTTP(wBypass, reqBypass)

	if wBypass.Code != http.StatusOK {
		t.Fatalf("expected status 200 for bypass, got %d", wBypass.Code)
	}
}

func TestSafeCounter_Inc(t *testing.T) {
	counter := &SafeCounter{}
	var expected int64 = 100
	done := make(chan struct{})

	for i := 0; i < 100; i++ {
		go func() {
			counter.Inc()
			done <- struct{}{}
		}()
	}

	for i := 0; i < 100; i++ {
		<-done
	}

	if counter.v != expected {
		t.Fatalf("expected counter value %d, got %d", expected, counter.v)
	}
}

func BenchmarkRateLimitKeyFormatting_Old(b *testing.B) {
	identifier := "usr_94a28b1c7e"
	currentMinute := time.Now().Unix() / 60

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkRateLimitKeyFormatting_New(b *testing.B) {
	identifier := "usr_94a28b1c7e"
	currentMinute := time.Now().Unix() / 60

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

func BenchmarkSafeCounter_AtomicInc(b *testing.B) {
	counter := &SafeCounter{}
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		counter.Inc()
	}
}
