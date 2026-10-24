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

func TestRateLimiterMiddleware_AllowsRequestsUnderLimit(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(RateLimiterMiddleware())
	router.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	req, _ := http.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = "192.168.1.100:12345"
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}
}

func TestRateLimiterMiddleware_ExceedsLimit(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(RateLimiterMiddleware())
	router.GET("/test-limit", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	testIP := "10.0.0.99:12345"

	// Rate limit is 60 requests
	for i := 0; i < RateLimit; i++ {
		req, _ := http.NewRequest(http.MethodGet, "/test-limit", nil)
		req.RemoteAddr = testIP
		w := httptest.NewRecorder()
		router.ServeHTTP(w, req)
		if w.Code != http.StatusOK {
			t.Fatalf("expected request %d to be allowed (status 200), got %d", i+1, w.Code)
		}
	}

	// 61st request should be blocked with 429
	req, _ := http.NewRequest(http.MethodGet, "/test-limit", nil)
	req.RemoteAddr = testIP
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	if w.Code != http.StatusTooManyRequests {
		t.Errorf("expected status 429 when exceeding rate limit, got %d", w.Code)
	}
}

func TestSafeCounter_Inc(t *testing.T) {
	counter := &SafeCounter{}
	var wg sync.WaitGroup
	numGoroutines := 100
	incrementsPerGoroutine := 100

	for i := 0; i < numGoroutines; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < incrementsPerGoroutine; j++ {
				counter.Inc()
			}
		}()
	}

	wg.Wait()
	expected := numGoroutines * incrementsPerGoroutine
	if val := counter.Inc() - 1; val != expected {
		t.Errorf("expected count %d, got %d", expected, val)
	}
}

func BenchmarkKeyFormattingConcat(b *testing.B) {
	identifier := "user_123456789"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

func BenchmarkKeyFormattingSprintf(b *testing.B) {
	identifier := "user_123456789"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

func BenchmarkSafeCounter_Inc(b *testing.B) {
	counter := &SafeCounter{}
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
