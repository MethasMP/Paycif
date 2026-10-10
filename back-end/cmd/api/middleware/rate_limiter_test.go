package middleware

import (
	"net/http"
	"net/http/httptest"
	"strconv"
	"sync"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestRateLimiterMiddleware_Basic(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RateLimiterMiddleware())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	for i := 0; i < RateLimit; i++ {
		req := httptest.NewRequest("GET", "/test", nil)
		req.Header.Set("X-Forwarded-For", "192.168.1.100")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		if w.Code != http.StatusOK {
			t.Fatalf("expected status 200 on request %d, got %d", i+1, w.Code)
		}
	}

	// 61st request should be rate limited
	req := httptest.NewRequest("GET", "/test", nil)
	req.Header.Set("X-Forwarded-For", "192.168.1.100")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusTooManyRequests {
		t.Fatalf("expected status 429 on request 61, got %d", w.Code)
	}
}

type MutexCounter struct {
	v int
	m sync.Mutex
}

func (c *MutexCounter) Inc() int {
	c.m.Lock()
	defer c.m.Unlock()
	c.v++
	return c.v
}

func BenchmarkKeyFormatting(b *testing.B) {
	identifier := "user_123456789"
	currentMinute := int64(1700000000)

	b.Run("fmt.Sprintf", func(b *testing.B) {
		b.ReportAllocs()
		for i := 0; i < b.N; i++ {
			_ = fmtSprintfKey(identifier, currentMinute)
		}
	})

	b.Run("strconv concatenation", func(b *testing.B) {
		b.ReportAllocs()
		for i := 0; i < b.N; i++ {
			_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
		}
	})
}

func BenchmarkSafeCounter(b *testing.B) {
	b.Run("MutexSafeCounter", func(b *testing.B) {
		mc := &MutexCounter{}
		b.ReportAllocs()
		b.RunParallel(func(pb *testing.PB) {
			for pb.Next() {
				mc.Inc()
			}
		})
	})

	b.Run("AtomicSafeCounter", func(b *testing.B) {
		sc := &SafeCounter{}
		b.ReportAllocs()
		b.RunParallel(func(pb *testing.PB) {
			for pb.Next() {
				sc.Inc()
			}
		})
	})
}
