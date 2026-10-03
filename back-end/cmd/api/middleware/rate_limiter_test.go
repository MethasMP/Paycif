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

func TestRateLimiterMiddleware_AllowsUnderLimit(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/test", nil)
	req.RemoteAddr = "192.168.1.100:12345"

	r.ServeHTTP(w, req)
	assert.Equal(t, http.StatusOK, w.Code)
}

func TestRateLimiterMiddleware_EnforcesLimit(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test-limit", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	ip := "192.168.1.200:12345"

	for i := 0; i < RateLimit; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest("GET", "/test-limit", nil)
		req.RemoteAddr = ip
		r.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code, "request %d should succeed", i+1)
	}

	// 61st request should be rate limited
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/test-limit", nil)
	req.RemoteAddr = ip
	r.ServeHTTP(w, req)
	assert.Equal(t, http.StatusTooManyRequests, w.Code)
}

func TestSafeCounter_AtomicIncrement(t *testing.T) {
	counter := &SafeCounter{}
	var wg sync.WaitGroup
	workers := 50
	increments := 100

	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < increments; j++ {
				counter.Inc()
			}
		}()
	}

	wg.Wait()
	assert.Equal(t, int64(workers*increments), counter.v)
}

// BenchmarkRateLimiterKeyFormatting_Sprintf measures performance of legacy fmt.Sprintf key construction.
func BenchmarkRateLimiterKeyFormatting_Sprintf(b *testing.B) {
	identifier := "user_123456789_abcdef"
	currentMinute := time.Now().Unix() / 60

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

// BenchmarkRateLimiterKeyFormatting_Concat measures performance of optimized string concatenation.
func BenchmarkRateLimiterKeyFormatting_Concat(b *testing.B) {
	identifier := "user_123456789_abcdef"
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

func (c *MutexCounter) Inc() int64 {
	c.mux.Lock()
	defer c.mux.Unlock()
	c.v++
	return c.v
}

// BenchmarkSafeCounter_Mutex measures contention under Mutex locking.
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

// BenchmarkSafeCounter_Atomic measures lock-free atomic increment performance.
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
