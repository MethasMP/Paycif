package middleware

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
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
	r.Use(func(c *gin.Context) {
		if uid := c.GetHeader("X-User-Id"); uid != "" {
			c.Set("user_id", uid)
		}
		c.Next()
	})
	r.Use(RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	userID := "test-user-rate-limit"

	// Initial requests below limit should succeed
	for i := 0; i < RateLimit; i++ {
		req := httptest.NewRequest(http.MethodGet, "/test", nil)
		req.Header.Set("X-User-Id", userID)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}

	// Next request should be rate limited (429)
	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("X-User-Id", userID)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	assert.Equal(t, http.StatusTooManyRequests, w.Code)
}

func TestRateLimiterMiddleware_BypassHeader(t *testing.T) {
	gin.SetMode(gin.TestMode)
	_ = os.Setenv("GIN_MODE", "debug")

	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	// Send requests with load test bypass header
	for i := 0; i < RateLimit+10; i++ {
		req := httptest.NewRequest(http.MethodGet, "/test", nil)
		req.Header.Set("X-Load-Test-User-Id", "load-test-user")
		w := httptest.NewRecorder()

		r.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}
}

// BenchmarkKeyFormatting_Concat measures direct string concatenation performance
func BenchmarkKeyFormatting_Concat(b *testing.B) {
	identifier := "user-12345678-abcd-efgh-9012"
	currentMinute := time.Now().Unix() / 60

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

// BenchmarkKeyFormatting_Sprintf measures fmt.Sprintf baseline performance
func BenchmarkKeyFormatting_Sprintf(b *testing.B) {
	identifier := "user-12345678-abcd-efgh-9012"
	currentMinute := time.Now().Unix() / 60

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

// BenchmarkSafeCounter_Atomic measures lock-free atomic increment performance
func BenchmarkSafeCounter_Atomic(b *testing.B) {
	var counter SafeCounter
	b.ReportAllocs()
	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}

type MutexCounter struct {
	v   int64
	mux sync.Mutex
}

func (m *MutexCounter) Inc() int64 {
	m.mux.Lock()
	m.v++
	val := m.v
	m.mux.Unlock()
	return val
}

// BenchmarkSafeCounter_Mutex measures baseline mutex-locked increment performance
func BenchmarkSafeCounter_Mutex(b *testing.B) {
	var counter MutexCounter
	b.ReportAllocs()
	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
