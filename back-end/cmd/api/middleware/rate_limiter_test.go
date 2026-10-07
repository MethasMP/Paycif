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
)

func TestRateLimiterMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	// 1. Send requests up to RateLimit (60)
	for i := 0; i < RateLimit; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest("GET", "/test", nil)
		req.RemoteAddr = "192.168.1.100:12345"
		r.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Fatalf("Expected status 200 on request %d, got %d", i+1, w.Code)
		}
	}

	// 2. The 61st request should be rate limited (429)
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/test", nil)
	req.RemoteAddr = "192.168.1.100:12345"
	r.ServeHTTP(w, req)

	if w.Code != http.StatusTooManyRequests {
		t.Fatalf("Expected status 429 when rate limit exceeded, got %d", w.Code)
	}

	// 3. Request with bypass header should succeed
	wBypass := httptest.NewRecorder()
	reqBypass, _ := http.NewRequest("GET", "/test", nil)
	reqBypass.Header.Set("X-Load-Test-User-Id", "load-test-bot")
	r.ServeHTTP(wBypass, reqBypass)

	if wBypass.Code != http.StatusOK {
		t.Fatalf("Expected status 200 with bypass header, got %d", wBypass.Code)
	}
}

func BenchmarkKeyFormattingOptimized(b *testing.B) {
	identifier := "user_1234567890_test_account"
	currentMinute := time.Now().Unix() / 60

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

func BenchmarkKeyFormattingSprintf(b *testing.B) {
	identifier := "user_1234567890_test_account"
	currentMinute := time.Now().Unix() / 60

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
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

func BenchmarkAtomicCounterParallel(b *testing.B) {
	counter := &SafeCounter{}
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}

func BenchmarkMutexCounterParallel(b *testing.B) {
	counter := &MutexCounter{}
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
