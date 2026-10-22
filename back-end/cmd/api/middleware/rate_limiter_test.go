package middleware_test

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"strconv"
	"sync"
	"testing"

	"paysif/cmd/api/middleware"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

func init() {
	gin.SetMode(gin.TestMode)
}

func TestRateLimiterMiddleware_Allowed(t *testing.T) {
	r := gin.New()
	r.Use(middleware.RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	req, _ := http.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = "192.168.1.100:12345"
	resp := httptest.NewRecorder()

	r.ServeHTTP(resp, req)

	assert.Equal(t, http.StatusOK, resp.Code)
	assert.Equal(t, "ok", resp.Body.String())
}

func TestRateLimiterMiddleware_Exceeded(t *testing.T) {
	r := gin.New()
	r.Use(middleware.RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	// Send Requests up to limit + 1
	for i := 0; i < middleware.RateLimit; i++ {
		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = "10.0.0.1:12345"
		resp := httptest.NewRecorder()
		r.ServeHTTP(resp, req)
		assert.Equal(t, http.StatusOK, resp.Code)
	}

	// 61st request should be rate limited (429)
	req, _ := http.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = "10.0.0.1:12345"
	resp := httptest.NewRecorder()
	r.ServeHTTP(resp, req)

	assert.Equal(t, http.StatusTooManyRequests, resp.Code)
}

// BenchmarkKeyFormatting_Sprintf benchmarks legacy fmt.Sprintf key construction
func BenchmarkKeyFormatting_Sprintf(b *testing.B) {
	identifier := "usr_1234567890_abcdef"
	minute := int64(28000000)

	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, minute)
	}
}

// BenchmarkKeyFormatting_Concat benchmarks optimized direct string concatenation
func BenchmarkKeyFormatting_Concat(b *testing.B) {
	identifier := "usr_1234567890_abcdef"
	minute := int64(28000000)

	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(minute, 10)
	}
}

// BenchmarkSafeCounter_Atomic benchmarks lock-free atomic SafeCounter increments
func BenchmarkSafeCounter_Atomic(b *testing.B) {
	counter := &middleware.SafeCounter{}

	b.ResetTimer()
	b.ReportAllocs()

	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}

// LegacySafeCounter with sync.Mutex for benchmark comparison
type LegacySafeCounter struct {
	v   int
	mux sync.Mutex
}

func (c *LegacySafeCounter) Inc() int {
	c.mux.Lock()
	defer c.mux.Unlock()
	c.v++
	return c.v
}

// BenchmarkSafeCounter_Mutex benchmarks legacy mutex SafeCounter increments
func BenchmarkSafeCounter_Mutex(b *testing.B) {
	counter := &LegacySafeCounter{}

	b.ResetTimer()
	b.ReportAllocs()

	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
