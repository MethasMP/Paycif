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

func TestRateLimiterMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	// Make 60 successful requests
	for i := 0; i < RateLimit; i++ {
		req := httptest.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = "192.168.1.1:12345"
		resp := httptest.NewRecorder()
		r.ServeHTTP(resp, req)

		assert.Equal(t, http.StatusOK, resp.Code, "Request %d should be allowed", i+1)
	}

	// 61st request should be rate limited
	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = "192.168.1.1:12345"
	resp := httptest.NewRecorder()
	r.ServeHTTP(resp, req)

	assert.Equal(t, http.StatusTooManyRequests, resp.Code)
}

func TestRateLimiterMiddleware_ConcurrentRequests(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/concurrent", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	var wg sync.WaitGroup
	allowedCount := int64(0)
	blockedCount := int64(0)
	var mu sync.Mutex

	totalRequests := 100
	for i := 0; i < totalRequests; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			req := httptest.NewRequest(http.MethodGet, "/concurrent", nil)
			req.RemoteAddr = "10.0.0.1:54321"
			resp := httptest.NewRecorder()
			r.ServeHTTP(resp, req)

			mu.Lock()
			if resp.Code == http.StatusOK {
				allowedCount++
			} else if resp.Code == http.StatusTooManyRequests {
				blockedCount++
			}
			mu.Unlock()
		}()
	}

	wg.Wait()

	assert.Equal(t, int64(RateLimit), allowedCount)
	assert.Equal(t, int64(totalRequests-RateLimit), blockedCount)
}

func BenchmarkRateLimiter_KeyFormatting_DirectConcat(b *testing.B) {
	identifier := "user_123456789"
	minute := int64(29871234)

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(minute, 10)
	}
}

func BenchmarkRateLimiter_KeyFormatting_Sprintf(b *testing.B) {
	identifier := "user_123456789"
	minute := int64(29871234)

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, minute)
	}
}

func BenchmarkSafeCounter_AtomicInc(b *testing.B) {
	counter := &SafeCounter{}

	b.ResetTimer()
	b.ReportAllocs()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
