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

func TestRateLimiterMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)

	t.Run("Allows requests within limit and blocks when exceeded", func(t *testing.T) {
		r := gin.New()
		r.Use(RateLimiterMiddleware())
		r.GET("/test", func(c *gin.Context) {
			c.String(http.StatusOK, "ok")
		})

		for i := 0; i < RateLimit; i++ {
			w := httptest.NewRecorder()
			req, _ := http.NewRequest("GET", "/test", nil)
			req.RemoteAddr = "192.168.1.1:12345"
			r.ServeHTTP(w, req)
			if w.Code != http.StatusOK {
				t.Fatalf("Expected status 200 on request %d, got %d", i+1, w.Code)
			}
		}

		// 61st request should be rate limited
		w := httptest.NewRecorder()
		req, _ := http.NewRequest("GET", "/test", nil)
		req.RemoteAddr = "192.168.1.1:12345"
		r.ServeHTTP(w, req)
		if w.Code != http.StatusTooManyRequests {
			t.Fatalf("Expected status 429 when rate limit exceeded, got %d", w.Code)
		}
	})

	t.Run("Bypasses rate limit when load test header is present in non-release mode", func(t *testing.T) {
		r := gin.New()
		r.Use(RateLimiterMiddleware())
		r.GET("/test", func(c *gin.Context) {
			c.String(http.StatusOK, "ok")
		})

		// Make more requests than RateLimit with bypass header
		for i := 0; i < RateLimit+10; i++ {
			w := httptest.NewRecorder()
			req, _ := http.NewRequest("GET", "/test", nil)
			req.Header.Set("X-Load-Test-User-Id", "load-tester-1")
			r.ServeHTTP(w, req)
			if w.Code != http.StatusOK {
				t.Fatalf("Expected status 200 with bypass header on request %d, got %d", i+1, w.Code)
			}
		}
	})
}

// Benchmark key formatting: Sprintf vs Direct Concatenation
func BenchmarkKeyFormatSprintf(b *testing.B) {
	identifier := "user_123456789_test_identifier"
	minute := int64(29876543)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, minute)
	}
}

func BenchmarkKeyFormatConcat(b *testing.B) {
	identifier := "user_123456789_test_identifier"
	minute := int64(29876543)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(minute, 10)
	}
}

// Benchmark SafeCounter: Mutex vs Atomic
type mutexCounter struct {
	v   int64
	mux sync.Mutex
}

func (c *mutexCounter) Inc() int64 {
	c.mux.Lock()
	defer c.mux.Unlock()
	c.v++
	return c.v
}

func BenchmarkSafeCounterMutex(b *testing.B) {
	c := &mutexCounter{}
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			c.Inc()
		}
	})
}

func BenchmarkSafeCounterAtomic(b *testing.B) {
	c := &SafeCounter{}
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			c.Inc()
		}
	})
}
