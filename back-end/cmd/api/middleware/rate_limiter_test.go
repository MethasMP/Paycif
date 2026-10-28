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
		c.String(http.StatusOK, "ok")
	})

	// Perform requests up to RateLimit
	for i := 0; i < RateLimit; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = "192.168.1.100:12345"
		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}

	// Next request should be rate limited (429)
	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = "192.168.1.100:12345"
	router.ServeHTTP(w, req)
	assert.Equal(t, http.StatusTooManyRequests, w.Code)
}

func TestSafeCounter_Inc(t *testing.T) {
	counter := &SafeCounter{}
	var wg sync.WaitGroup
	workers := 100
	iterations := 1000

	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				counter.Inc()
			}
		}()
	}
	wg.Wait()

	assert.Equal(t, int64(workers*iterations), counter.Inc()-1)
}

func BenchmarkKeyFormatting_Sprintf(b *testing.B) {
	identifier := "user_123456789"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkKeyFormatting_Optimized(b *testing.B) {
	identifier := "user_123456789"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
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
