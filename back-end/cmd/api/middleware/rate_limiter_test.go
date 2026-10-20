package middleware

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"strconv"
	"sync"
	"sync/atomic"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

func TestSafeCounter_Inc(t *testing.T) {
	counter := &SafeCounter{}
	var wg sync.WaitGroup

	numGoroutines := 100
	numIncrements := 1000

	for i := 0; i < numGoroutines; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < numIncrements; j++ {
				counter.Inc()
			}
		}()
	}

	wg.Wait()
	assert.Equal(t, int64(numGoroutines*numIncrements), counter.v)
}

func TestRateLimiterMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	// Make RateLimit requests which should pass
	for i := 0; i < RateLimit; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = "192.168.1.1:12345"
		r.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}

	// The RateLimit + 1 request should be rate limited
	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = "192.168.1.1:12345"
	r.ServeHTTP(w, req)
	assert.Equal(t, http.StatusTooManyRequests, w.Code)
}

type MutexSafeCounter struct {
	v   int
	mux sync.Mutex
}

func (c *MutexSafeCounter) Inc() int {
	c.mux.Lock()
	defer c.mux.Unlock()
	c.v++
	return c.v
}

type AtomicSafeCounter struct {
	v int64
}

func (c *AtomicSafeCounter) Inc() int {
	return int(atomic.AddInt64(&c.v, 1))
}

func BenchmarkKeyFormatSprintf(b *testing.B) {
	identifier := "user_123456789_test"
	minute := int64(28000000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, minute)
	}
}

func BenchmarkKeyFormatConcat(b *testing.B) {
	identifier := "user_123456789_test"
	minute := int64(28000000)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(minute, 10)
	}
}

func BenchmarkCounterMutexParallel(b *testing.B) {
	counter := &MutexSafeCounter{}
	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}

func BenchmarkCounterAtomicParallel(b *testing.B) {
	counter := &AtomicSafeCounter{}
	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
