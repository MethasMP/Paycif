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
	"github.com/stretchr/testify/assert"
)

func TestRateLimiterMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)

	clearMemoryStore := func() {
		memoryStore.Range(func(key, value interface{}) bool {
			memoryStore.Delete(key)
			return true
		})
	}

	t.Run("allows requests within rate limit", func(t *testing.T) {
		clearMemoryStore()
		router := gin.New()
		router.Use(RateLimiterMiddleware())
		router.GET("/test", func(c *gin.Context) {
			c.String(http.StatusOK, "OK")
		})

		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = "192.168.1.100:12345"
		w := httptest.NewRecorder()

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
		assert.Equal(t, "OK", w.Body.String())
	})

	t.Run("blocks requests when rate limit is exceeded", func(t *testing.T) {
		clearMemoryStore()
		router := gin.New()
		router.Use(RateLimiterMiddleware())
		router.GET("/test-exceed", func(c *gin.Context) {
			c.String(http.StatusOK, "OK")
		})

		testIP := "10.0.0.99:12345"
		for i := 0; i < RateLimit; i++ {
			req, _ := http.NewRequest(http.MethodGet, "/test-exceed", nil)
			req.RemoteAddr = testIP
			w := httptest.NewRecorder()
			router.ServeHTTP(w, req)
			assert.Equal(t, http.StatusOK, w.Code)
		}

		// The 61st request should be rate-limited
		req, _ := http.NewRequest(http.MethodGet, "/test-exceed", nil)
		req.RemoteAddr = testIP
		w := httptest.NewRecorder()
		router.ServeHTTP(w, req)

		assert.Equal(t, http.StatusTooManyRequests, w.Code)
		assert.Contains(t, w.Body.String(), "Rate limit exceeded")
	})

	t.Run("bypasses rate limit when load test user header is set", func(t *testing.T) {
		router := gin.New()
		router.Use(RateLimiterMiddleware())
		router.GET("/test-bypass", func(c *gin.Context) {
			c.String(http.StatusOK, "OK")
		})

		req, _ := http.NewRequest(http.MethodGet, "/test-bypass", nil)
		req.Header.Set("X-Load-Test-User-Id", "load-tester-1")
		w := httptest.NewRecorder()

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	})
}

// MutexCounter represents legacy sync.Mutex implementation for benchmark comparison
type MutexCounter struct {
	v   int64
	mux sync.Mutex
}

func (mc *MutexCounter) Inc() int64 {
	mc.mux.Lock()
	defer mc.mux.Unlock()
	mc.v++
	return mc.v
}

func BenchmarkKeyFormatting_Sprintf(b *testing.B) {
	identifier := "usr_987654321"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkKeyFormatting_DirectConcat(b *testing.B) {
	identifier := "usr_987654321"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

func BenchmarkSafeCounter_Mutex(b *testing.B) {
	mc := &MutexCounter{}
	b.ResetTimer()
	b.ReportAllocs()

	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			mc.Inc()
		}
	})
}

func BenchmarkSafeCounter_Atomic(b *testing.B) {
	sc := &SafeCounter{}
	b.ResetTimer()
	b.ReportAllocs()

	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			sc.Inc()
		}
	})
}

func BenchmarkSafeCounter_AtomicSingleThread(b *testing.B) {
	var v int64
	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		atomic.AddInt64(&v, 1)
	}
}
