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

func TestRateLimiterMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)

	t.Run("allows requests within rate limit", func(t *testing.T) {
		r := gin.New()
		r.Use(func(c *gin.Context) {
			c.Set("user_id", "user-allowed-1")
			c.Next()
		})
		r.Use(RateLimiterMiddleware())
		r.GET("/test", func(c *gin.Context) {
			c.String(http.StatusOK, "ok")
		})

		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		assert.Equal(t, http.StatusOK, w.Code)
		assert.Equal(t, "ok", w.Body.String())
	})

	t.Run("bypasses for load test header in dev mode", func(t *testing.T) {
		r := gin.New()
		r.Use(RateLimiterMiddleware())
		r.GET("/test", func(c *gin.Context) {
			c.String(http.StatusOK, "ok")
		})

		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		req.Header.Set("X-Load-Test-User-Id", "bypass-user-123")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		assert.Equal(t, http.StatusOK, w.Code)
	})

	t.Run("blocks when rate limit is exceeded", func(t *testing.T) {
		r := gin.New()
		testUserID := "user-block-test-99"
		r.Use(func(c *gin.Context) {
			c.Set("user_id", testUserID)
			c.Next()
		})
		r.Use(RateLimiterMiddleware())
		r.GET("/test", func(c *gin.Context) {
			c.String(http.StatusOK, "ok")
		})

		// Send RateLimit (60) requests - all should succeed
		for i := 0; i < RateLimit; i++ {
			req, _ := http.NewRequest(http.MethodGet, "/test", nil)
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)
			assert.Equal(t, http.StatusOK, w.Code)
		}

		// 61st request should be rejected with 429
		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		assert.Equal(t, http.StatusTooManyRequests, w.Code)
		assert.Contains(t, w.Body.String(), "Rate limit exceeded")
	})
}

func TestSafeCounter(t *testing.T) {
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
	assert.Equal(t, workers*iterations, counter.Inc()-1)
}

// Benchmarks for Key Formatting: Sprintf vs Direct Concatenation
func BenchmarkKeyFormat_Sprintf(b *testing.B) {
	identifier := "user-12345678-abcdef"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkKeyFormat_Concat(b *testing.B) {
	identifier := "user-12345678-abcdef"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

// Benchmarks for Counter Concurrency: Mutex vs Atomic
type MutexCounter struct {
	v   int
	mux sync.Mutex
}

func (m *MutexCounter) Inc() int {
	m.mux.Lock()
	defer m.mux.Unlock()
	m.v++
	return m.v
}

func BenchmarkSafeCounter_Mutex(b *testing.B) {
	c := &MutexCounter{}
	b.ResetTimer()
	b.ReportAllocs()

	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			c.Inc()
		}
	})
}

func BenchmarkSafeCounter_Atomic(b *testing.B) {
	c := &SafeCounter{}
	b.ResetTimer()
	b.ReportAllocs()

	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			c.Inc()
		}
	})
}
