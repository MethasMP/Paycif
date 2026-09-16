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
)

func TestRateLimiterMiddleware_EnforcesLimit(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(RateLimiterMiddleware())
	router.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	for i := 0; i < RateLimit; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest("GET", "/test", nil)
		req.RemoteAddr = "192.168.1.1:12345"
		router.ServeHTTP(w, req)
		if w.Code != http.StatusOK {
			t.Fatalf("expected status 200 on iteration %d, got %d", i, w.Code)
		}
	}

	// 61st request should be blocked
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/test", nil)
	req.RemoteAddr = "192.168.1.1:12345"
	router.ServeHTTP(w, req)
	if w.Code != http.StatusTooManyRequests {
		t.Fatalf("expected status 429 on rate limit exceed, got %d", w.Code)
	}
}

func BenchmarkKeyFormatting_Sprintf(b *testing.B) {
	identifier := "usr_123456789"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkKeyFormatting_Concat(b *testing.B) {
	identifier := "usr_123456789"
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
	c.v++
	v := c.v
	c.mux.Unlock()
	return v
}

type AtomicCounter struct {
	v int64
}

func (c *AtomicCounter) Inc() int64 {
	return atomic.AddInt64(&c.v, 1)
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
	counter := &AtomicCounter{}
	b.ResetTimer()
	b.ReportAllocs()

	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
