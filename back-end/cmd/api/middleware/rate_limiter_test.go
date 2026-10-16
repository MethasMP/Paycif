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
	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	// Make 60 allowed requests
	for i := 0; i < RateLimit; i++ {
		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		req.Header.Set("X-Forwarded-For", "192.168.1.100")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code, "Request %d should be allowed", i+1)
	}

	// 61st request should be blocked with 429
	req, _ := http.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("X-Forwarded-For", "192.168.1.100")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	assert.Equal(t, http.StatusTooManyRequests, w.Code, "61st request should be rate limited")
}

func TestRateLimiterMiddleware_LoadTestBypass(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	// Bypass header allows exceeding rate limit
	for i := 0; i < RateLimit+10; i++ {
		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		req.Header.Set("X-Load-Test-User-Id", "load-test-bot-1")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}
}

func TestSafeCounter_ConcurrentInc(t *testing.T) {
	counter := &SafeCounter{}
	var wg sync.WaitGroup

	goroutines := 100
	increments := 1000

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < increments; j++ {
				counter.Inc()
			}
		}()
	}

	wg.Wait()
	assert.Equal(t, int64(goroutines*increments), counter.Inc()-1)
}

func BenchmarkKeyFormatting_Sprintf(b *testing.B) {
	identifier := "usr_987654321"
	minute := time.Now().Unix() / 60
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, minute)
	}
}

func BenchmarkKeyFormatting_Concat(b *testing.B) {
	identifier := "usr_987654321"
	minute := time.Now().Unix() / 60
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(minute, 10)
	}
}

func BenchmarkSafeCounter_Atomic(b *testing.B) {
	counter := &SafeCounter{}
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
