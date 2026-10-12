package middleware

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"strconv"
	"sync"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestSafeCounter_Inc(t *testing.T) {
	c := &SafeCounter{}
	var wg sync.WaitGroup
	workers := 100
	iterations := 1000

	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				c.Inc()
			}
		}()
	}

	wg.Wait()
	expected := workers * iterations
	if val := c.Inc(); val != expected+1 {
		t.Errorf("expected counter value %d, got %d", expected+1, val)
	}
}

func TestRateLimiterMiddleware_KeyFormatAndLimit(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	for i := 1; i <= RateLimit; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = "192.168.1.100:12345"
		r.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Fatalf("request %d failed with status %d, expected %d", i, w.Code, http.StatusOK)
		}
	}

	// Next request should be rate limited
	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = "192.168.1.100:12345"
	r.ServeHTTP(w, req)

	if w.Code != http.StatusTooManyRequests {
		t.Fatalf("expected rate limit status 429, got %d", w.Code)
	}
}

func BenchmarkKeyFormatting_Sprintf(b *testing.B) {
	identifier := "user-123456789"
	currentMinute := int64(28000000)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkKeyFormatting_Concat(b *testing.B) {
	identifier := "user-123456789"
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

func (mc *MutexCounter) Inc() int {
	mc.m.Lock()
	defer mc.m.Unlock()
	mc.v++
	return mc.v
}

func BenchmarkCounter_Mutex(b *testing.B) {
	mc := &MutexCounter{}
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			mc.Inc()
		}
	})
}

func BenchmarkCounter_Atomic(b *testing.B) {
	sc := &SafeCounter{}
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			sc.Inc()
		}
	})
}
