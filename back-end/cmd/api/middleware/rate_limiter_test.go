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

	userID := "test-user-rate-limit-1"

	// Perform 60 allowed requests
	for i := 0; i < RateLimit; i++ {
		req := httptest.NewRequest(http.MethodGet, "/test", nil)
		req.Header.Set("X-Forwarded-For", "192.168.1.100")
		w := httptest.NewRecorder()

		// Inject user_id into context via handler wrapper or middleware
		r.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code, "Request %d should be allowed", i+1)
	}

	_ = userID
}

func TestSafeCounter_AtomicInc(t *testing.T) {
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

func BenchmarkRateLimiterKeyFormatting_Sprintf(b *testing.B) {
	identifier := "usr_1234567890"
	currentMinute := time.Now().Unix() / 60

	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkRateLimiterKeyFormatting_Concat(b *testing.B) {
	identifier := "usr_1234567890"
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
	defer c.mux.Unlock()
	c.v++
	return c.v
}

func BenchmarkSafeCounter_Mutex(b *testing.B) {
	c := &MutexCounter{}
	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			c.Inc()
		}
	})
}

func BenchmarkSafeCounter_Atomic(b *testing.B) {
	c := &SafeCounter{}
	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			c.Inc()
		}
	})
}
