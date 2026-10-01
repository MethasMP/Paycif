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

func TestRateLimiterMiddleware_AllowedAndExceeded(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(RateLimiterMiddleware())
	router.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	// Make 60 requests for a unique IP (should succeed)
	ip := "192.168.1.100"
	for i := 0; i < RateLimit; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = ip + ":12345"
		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}

	// 61st request should be rate limited (429)
	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = ip + ":12345"
	router.ServeHTTP(w, req)
	assert.Equal(t, http.StatusTooManyRequests, w.Code)
}

func TestRateLimiterMiddleware_BypassHeader(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(RateLimiterMiddleware())
	router.GET("/test-bypass", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	// Make 65 requests with load test bypass header
	ip := "10.0.0.50"
	for i := 0; i < 65; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodGet, "/test-bypass", nil)
		req.RemoteAddr = ip + ":12345"
		req.Header.Set("X-Load-Test-User-Id", "load-tester-1")
		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}
}

func BenchmarkRateLimiterKeyFormatting_Sprintf(b *testing.B) {
	identifier := "user_1234567890_abcdef"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkRateLimiterKeyFormatting_Concat(b *testing.B) {
	identifier := "user_1234567890_abcdef"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

func BenchmarkSafeCounterInc(b *testing.B) {
	counter := &SafeCounter{}
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
	v := m.v
	m.mux.Unlock()
	return v
}

func BenchmarkMutexCounterInc(b *testing.B) {
	counter := &MutexCounter{}
	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
