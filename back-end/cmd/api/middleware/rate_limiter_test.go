package middleware

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

func TestRateLimiterMiddleware_Allowed(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/test", nil)
	r.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	assert.Equal(t, "ok", w.Body.String())
}

func TestRateLimiterMiddleware_LimitExceeded(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test-limit", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	// Perform 60 requests (allowed limit)
	for i := 0; i < RateLimit; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodGet, "/test-limit", nil)
		req.RemoteAddr = "192.168.1.100:12345"
		r.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}

	// 61st request should be blocked
	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/test-limit", nil)
	req.RemoteAddr = "192.168.1.100:12345"
	r.ServeHTTP(w, req)
	assert.Equal(t, http.StatusTooManyRequests, w.Code)
}

func TestRateLimiterMiddleware_LoadTestBypass(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test-bypass", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	// Send requests with X-Load-Test-User-Id beyond limit
	for i := 0; i < RateLimit+5; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodGet, "/test-bypass", nil)
		req.Header.Set("X-Load-Test-User-Id", "test-user-123")
		r.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}
}

func BenchmarkRateLimiterKey_Sprintf(b *testing.B) {
	identifier := "user_12345678-1234-1234-1234-123456789abc"
	currentMinute := time.Now().Unix() / 60

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkRateLimiterKey_Concat(b *testing.B) {
	identifier := "user_12345678-1234-1234-1234-123456789abc"
	currentMinute := time.Now().Unix() / 60

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}
