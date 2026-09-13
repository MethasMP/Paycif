package middleware

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"strconv"
	"sync"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

func TestRateLimiterMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.Use(RateLimiterMiddleware())
	router.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	// 1. Send RateLimit allowed requests (60 requests)
	for i := 0; i < RateLimit; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = "192.168.1.100:12345"
		router.ServeHTTP(w, req)
		if w.Code != http.StatusOK {
			t.Fatalf("Expected status 200 on request %d, got %d", i+1, w.Code)
		}
	}

	// 2. 61st request should be blocked with HTTP 429 Too Many Requests
	wBlocked := httptest.NewRecorder()
	reqBlocked, _ := http.NewRequest(http.MethodGet, "/test", nil)
	reqBlocked.RemoteAddr = "192.168.1.100:12345"
	router.ServeHTTP(wBlocked, reqBlocked)
	if wBlocked.Code != http.StatusTooManyRequests {
		t.Fatalf("Expected status 429 when rate limit exceeded, got %d", wBlocked.Code)
	}

	// 3. Different IP should still be allowed
	wOtherIP := httptest.NewRecorder()
	reqOtherIP, _ := http.NewRequest(http.MethodGet, "/test", nil)
	reqOtherIP.RemoteAddr = "192.168.1.101:12345"
	router.ServeHTTP(wOtherIP, reqOtherIP)
	if wOtherIP.Code != http.StatusOK {
		t.Fatalf("Expected status 200 for different IP, got %d", wOtherIP.Code)
	}

	// 4. Bypass header should skip rate limiting
	wBypass := httptest.NewRecorder()
	reqBypass, _ := http.NewRequest(http.MethodGet, "/test", nil)
	reqBypass.RemoteAddr = "192.168.1.100:12345"
	reqBypass.Header.Set("X-Load-Test-User-Id", "test-user-123")
	router.ServeHTTP(wBypass, reqBypass)
	if wBypass.Code != http.StatusOK {
		t.Fatalf("Expected status 200 with bypass header, got %d", wBypass.Code)
	}
}

// Legacy Mutex-based SafeCounter for benchmark comparison
type legacySafeCounter struct {
	v   int
	mux sync.Mutex
}

func (c *legacySafeCounter) Inc() int {
	c.mux.Lock()
	defer c.mux.Unlock()
	c.v++
	return c.v
}

func BenchmarkKeyFormatting_Sprintf(b *testing.B) {
	identifier := "user_987654321_test"
	currentMinute := time.Now().Unix() / 60

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkKeyFormatting_Concat(b *testing.B) {
	identifier := "user_987654321_test"
	currentMinute := time.Now().Unix() / 60

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

func BenchmarkCounter_Mutex(b *testing.B) {
	counter := &legacySafeCounter{}

	b.ResetTimer()
	b.ReportAllocs()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			_ = counter.Inc()
		}
	})
}

func BenchmarkCounter_Atomic(b *testing.B) {
	counter := &SafeCounter{}

	b.ResetTimer()
	b.ReportAllocs()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			_ = counter.Inc()
		}
	})
}
