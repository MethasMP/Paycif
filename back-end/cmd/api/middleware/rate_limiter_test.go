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

func TestRateLimiterMiddleware_AllowsRequestsWithinLimit(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(RateLimiterMiddleware())
	router.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	for i := 0; i < RateLimit; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = "192.168.1.100:12345"
		router.ServeHTTP(w, req)

		assert.Equal(t, http.StatusOK, w.Code, "Request %d should be allowed", i+1)
	}
}

func TestRateLimiterMiddleware_BlocksExceedingRequests(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(RateLimiterMiddleware())
	router.GET("/test-exceed", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	for i := 0; i < RateLimit; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodGet, "/test-exceed", nil)
		req.RemoteAddr = "192.168.1.101:12345"
		router.ServeHTTP(w, req)
	}

	// 61st request should fail with 429 Too Many Requests
	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/test-exceed", nil)
	req.RemoteAddr = "192.168.1.101:12345"
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusTooManyRequests, w.Code)
}

func TestRateLimiterMiddleware_BypassHeader(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(RateLimiterMiddleware())
	router.GET("/test-bypass", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	// Send more requests than RateLimit with bypass header
	for i := 0; i < RateLimit+10; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodGet, "/test-bypass", nil)
		req.Header.Set("X-Load-Test-User-Id", "test-user-123")
		req.RemoteAddr = "192.168.1.102:12345"
		router.ServeHTTP(w, req)

		assert.Equal(t, http.StatusOK, w.Code)
	}
}

func BenchmarkRateLimitKey_Sprintf(b *testing.B) {
	identifier := "user_123456789"
	currentMinute := time.Now().Unix() / 60

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkRateLimitKey_Concat(b *testing.B) {
	identifier := "user_123456789"
	currentMinute := time.Now().Unix() / 60

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

type MutexCounter struct {
	v   int64
	mux sync.Mutex
}

func (m *MutexCounter) Inc() int64 {
	m.mux.Lock()
	defer m.mux.Unlock()
	m.v++
	return m.v
}

func BenchmarkSafeCounter_Mutex(b *testing.B) {
	counter := &MutexCounter{}
	b.ResetTimer()
	b.ReportAllocs()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}

func BenchmarkSafeCounter_Atomic(b *testing.B) {
	counter := &SafeCounter{}
	b.ResetTimer()
	b.ReportAllocs()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
