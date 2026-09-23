package middleware

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"strconv"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

func TestRateLimiterMiddleware_AllowedAndExceeded(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	// Perform 60 requests - all should pass (RateLimit = 60)
	for i := 0; i < RateLimit; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = "192.168.1.100:12345"
		r.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}

	// 61st request - should be blocked with HTTP 429
	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = "192.168.1.100:12345"
	r.ServeHTTP(w, req)
	assert.Equal(t, http.StatusTooManyRequests, w.Code)
}

func TestRateLimiterMiddleware_ConcurrentRequests(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/concurrent", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	var wg sync.WaitGroup
	workers := 100
	statuses := make(chan int, workers)

	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			w := httptest.NewRecorder()
			req, _ := http.NewRequest(http.MethodGet, "/concurrent", nil)
			req.RemoteAddr = "10.0.0.1:54321"
			r.ServeHTTP(w, req)
			statuses <- w.Code
		}()
	}

	wg.Wait()
	close(statuses)

	okCount := 0
	tooManyCount := 0
	for code := range statuses {
		if code == http.StatusOK {
			okCount++
		} else if code == http.StatusTooManyRequests {
			tooManyCount++
		}
	}

	assert.Equal(t, RateLimit, okCount)
	assert.Equal(t, workers-RateLimit, tooManyCount)
}

// BenchmarkKeyFormatting_Sprintf benchmarks legacy fmt.Sprintf key construction
func BenchmarkKeyFormatting_Sprintf(b *testing.B) {
	identifier := "user_123456789"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

// BenchmarkKeyFormatting_Concat benchmarks direct string concatenation key construction
func BenchmarkKeyFormatting_Concat(b *testing.B) {
	identifier := "user_123456789"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

type LegacyMutexCounter struct {
	v   int
	mux sync.Mutex
}

func (c *LegacyMutexCounter) Inc() int {
	c.mux.Lock()
	defer c.mux.Unlock()
	c.v++
	return c.v
}

type AtomicCounter struct {
	v int64
}

func (c *AtomicCounter) Inc() int64 {
	return atomic.AddInt64(&c.v, 1)
}

func BenchmarkCounter_Mutex(b *testing.B) {
	counter := &LegacyMutexCounter{}
	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}

func BenchmarkCounter_Atomic(b *testing.B) {
	counter := &AtomicCounter{}
	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
