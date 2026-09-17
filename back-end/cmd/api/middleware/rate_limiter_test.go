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

	// Make 60 requests -> should all succeed
	for i := 0; i < RateLimit; i++ {
		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = "192.168.1.100:12345"
		w := httptest.NewRecorder()
		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}

	// 61st request -> should be rate limited (429)
	req, _ := http.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = "192.168.1.100:12345"
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	assert.Equal(t, http.StatusTooManyRequests, w.Code)
}

func TestRateLimiterKeyFormatting(t *testing.T) {
	identifier := "user_12345"
	currentMinute := time.Now().Unix() / 60

	// Optimized direct string concatenation
	optimizedKey := "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	// Expected legacy format
	legacyKey := fmt.Sprintf("rate:%s:%d", identifier, currentMinute)

	assert.Equal(t, legacyKey, optimizedKey)
}

func BenchmarkRateLimiterKeyFormatting_Optimized(b *testing.B) {
	identifier := "user_987654321_test"
	currentMinute := int64(29532810)

	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

func BenchmarkRateLimiterKeyFormatting_LegacySprintf(b *testing.B) {
	identifier := "user_987654321_test"
	currentMinute := int64(29532810)

	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkSafeCounterInc_Atomic(b *testing.B) {
	counter := &SafeCounter{}

	b.ResetTimer()
	b.ReportAllocs()

	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}

type legacyMutexCounter struct {
	v   int
	mux sync.Mutex
}

func (c *legacyMutexCounter) Inc() int {
	c.mux.Lock()
	defer c.mux.Unlock()
	c.v++
	return c.v
}

func BenchmarkSafeCounterInc_Mutex(b *testing.B) {
	counter := &legacyMutexCounter{}

	b.ResetTimer()
	b.ReportAllocs()

	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
