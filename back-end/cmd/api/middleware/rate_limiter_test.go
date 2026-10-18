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

	// Perform 60 requests -> all should succeed (200 OK)
	for i := 0; i < RateLimit; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = "192.168.1.1:12345"
		r.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}

	// 61st request -> should be rate limited (429 Too Many Requests)
	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = "192.168.1.1:12345"
	r.ServeHTTP(w, req)
	assert.Equal(t, http.StatusTooManyRequests, w.Code)
}

func TestSafeCounter_Inc(t *testing.T) {
	var counter SafeCounter
	var wg sync.WaitGroup
	numGoroutines := 100
	incrementsPerGoroutine := 1000

	wg.Add(numGoroutines)
	for i := 0; i < numGoroutines; i++ {
		go func() {
			defer wg.Done()
			for j := 0; j < incrementsPerGoroutine; j++ {
				counter.Inc()
			}
		}()
	}
	wg.Wait()

	assert.Equal(t, numGoroutines*incrementsPerGoroutine, counter.Inc()-1)
}

// Mutex-based SafeCounter for benchmark comparison
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

func BenchmarkKeyFormatting_Sprintf(b *testing.B) {
	identifier := "usr_1234567890"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkKeyFormatting_Concat(b *testing.B) {
	identifier := "usr_1234567890"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

func BenchmarkSafeCounter_Mutex(b *testing.B) {
	var counter MutexSafeCounter
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}

func BenchmarkSafeCounter_Atomic(b *testing.B) {
	var counter SafeCounter
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
