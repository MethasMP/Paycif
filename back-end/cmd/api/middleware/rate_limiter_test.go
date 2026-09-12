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
	"github.com/stretchr/testify/assert"
)

func TestRateLimiterMiddleware_AllowAndLimit(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	// Make 60 allowed requests with unique IP address for this test
	testIP := "192.168.1.100:12345"
	for i := 0; i < RateLimit; i++ {
		req := httptest.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = testIP
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}

	// 61st request should be rate limited (429)
	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = testIP
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	assert.Equal(t, http.StatusTooManyRequests, w.Code)
}

func TestRateLimiterMiddleware_LoadTestBypass(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	// With X-Load-Test-User-Id header, request should bypass rate limiting even after RateLimit requests
	for i := 0; i < RateLimit+5; i++ {
		req := httptest.NewRequest(http.MethodGet, "/test", nil)
		req.Header.Set("X-Load-Test-User-Id", "test-user-123")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}
}

func BenchmarkRateLimitKey_Sprintf(b *testing.B) {
	identifier := "user_123456789_test"
	currentMinute := time.Now().Unix() / 60

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkRateLimitKey_Concat(b *testing.B) {
	identifier := "user_123456789_test"
	currentMinute := time.Now().Unix() / 60

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

type MutexCounter struct {
	v   int64
	mux sync.Mutex
}

func (c *MutexCounter) Inc() int64 {
	c.mux.Lock()
	defer c.mux.Unlock()
	c.v++
	return c.v
}

func BenchmarkCounter_Mutex(b *testing.B) {
	c := &MutexCounter{}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = c.Inc()
	}
}

func BenchmarkCounter_Atomic(b *testing.B) {
	c := &SafeCounter{}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = c.Inc()
	}
}
