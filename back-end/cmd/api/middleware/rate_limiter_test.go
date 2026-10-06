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

func TestRateLimiterMiddleware_AllowsRequestsUnderLimit(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	req, _ := http.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = "192.168.1.100:12345"
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)
	assert.Equal(t, http.StatusOK, w.Code)
}

func TestRateLimiterMiddleware_BlocksRequestsOverLimit(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test-limit", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	clientIP := "10.0.0.99:54321"

	for i := 0; i < RateLimit; i++ {
		req, _ := http.NewRequest(http.MethodGet, "/test-limit", nil)
		req.RemoteAddr = clientIP
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}

	// RateLimit + 1 request should be blocked
	req, _ := http.NewRequest(http.MethodGet, "/test-limit", nil)
	req.RemoteAddr = clientIP
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	assert.Equal(t, http.StatusTooManyRequests, w.Code)
}

func TestSafeCounter_AtomicIncrements(t *testing.T) {
	counter := &SafeCounter{}
	var wg sync.WaitGroup
	workers := 100
	incrementsPerWorker := 1000

	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < incrementsPerWorker; j++ {
				counter.Inc()
			}
		}()
	}

	wg.Wait()
	assert.Equal(t, workers*incrementsPerWorker, counter.Inc()-1)
}

func BenchmarkKeyFormatting_Sprintf(b *testing.B) {
	identifier := "usr_1234567890"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkKeyFormatting_DirectConcat(b *testing.B) {
	identifier := "usr_1234567890"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

type MutexCounter struct {
	v   int
	mux sync.Mutex
}

func (c *MutexCounter) Inc() int {
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
