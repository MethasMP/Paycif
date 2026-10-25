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

func TestRateLimiterMiddleware_AllowsUnderLimit(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(RateLimiterMiddleware())
	router.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/test", nil)
	req.RemoteAddr = "192.168.1.1:1234"
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
}

func TestRateLimiterMiddleware_ExceedsLimit(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(RateLimiterMiddleware())
	router.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	for i := 0; i < RateLimit; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest("GET", "/test", nil)
		req.RemoteAddr = "10.0.0.1:1234"
		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}

	// 61st request should be rate limited
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/test", nil)
	req.RemoteAddr = "10.0.0.1:1234"
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusTooManyRequests, w.Code)
}

func TestSafeCounter(t *testing.T) {
	counter := &SafeCounter{}
	var wg sync.WaitGroup
	workers := 50
	iterations := 100

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

	assert.Equal(t, int64(workers*iterations), counter.Value())
}

func BenchmarkKeyFormattingSprintf(b *testing.B) {
	identifier := "user_123456789"
	currentMinute := int64(28000000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkKeyFormattingConcat(b *testing.B) {
	identifier := "user_123456789"
	currentMinute := int64(28000000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

type MutexCounter struct {
	v int
	m sync.Mutex
}

func (c *MutexCounter) Inc() int {
	c.m.Lock()
	defer c.m.Unlock()
	c.v++
	return c.v
}

func BenchmarkMutexCounterParallel(b *testing.B) {
	counter := &MutexCounter{}
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}

func BenchmarkAtomicCounterParallel(b *testing.B) {
	counter := &SafeCounter{}
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
