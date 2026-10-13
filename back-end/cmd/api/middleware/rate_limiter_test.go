package middleware

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"strconv"
	"sync"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

func TestRateLimiterMiddleware_AllowedAndBlocked(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(RateLimiterMiddleware())
	router.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	// Perform requests up to limit
	for i := 0; i < RateLimit; i++ {
		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = "192.168.1.100:12345"
		resp := httptest.NewRecorder()
		router.ServeHTTP(resp, req)

		assert.Equal(t, http.StatusOK, resp.Code, "request %d should be allowed", i+1)
	}

	// Next request should be blocked with HTTP 429
	req, _ := http.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = "192.168.1.100:12345"
	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, req)

	assert.Equal(t, http.StatusTooManyRequests, resp.Code, "request exceeding limit should be rate limited")
}

func TestRateLimiterMiddleware_BypassHeader(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(RateLimiterMiddleware())
	router.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	// Request with load test bypass header should succeed even if rate limit is reached
	for i := 0; i < RateLimit+10; i++ {
		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		req.Header.Set("X-Load-Test-User-Id", "bypass-user")
		resp := httptest.NewRecorder()
		router.ServeHTTP(resp, req)

		assert.Equal(t, http.StatusOK, resp.Code)
	}
}

// BenchmarkKeyFormatting_Sprintf benchmarks legacy fmt.Sprintf key construction.
func BenchmarkKeyFormatting_Sprintf(b *testing.B) {
	identifier := "192.168.1.100"
	var currentMinute int64 = 29384729

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

// BenchmarkKeyFormatting_Concat benchmarks optimized string concatenation key construction.
func BenchmarkKeyFormatting_Concat(b *testing.B) {
	identifier := "192.168.1.100"
	var currentMinute int64 = 29384729

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

type mutexCounter struct {
	v   int
	mux sync.Mutex
}

func (c *mutexCounter) Inc() int {
	c.mux.Lock()
	defer c.mux.Unlock()
	c.v++
	return c.v
}

// BenchmarkSafeCounter_Mutex benchmarks mutex-based counter increments.
func BenchmarkSafeCounter_Mutex(b *testing.B) {
	counter := &mutexCounter{}
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}

// BenchmarkSafeCounter_Atomic benchmarks atomic lock-free counter increments.
func BenchmarkSafeCounter_Atomic(b *testing.B) {
	counter := &SafeCounter{}
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
