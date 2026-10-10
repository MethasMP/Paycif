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

func init() {
	gin.SetMode(gin.TestMode)
}

func TestRateLimiterMiddleware_Allowed(t *testing.T) {
	router := gin.New()
	router.Use(RateLimiterMiddleware())
	router.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/test", nil)
	req.RemoteAddr = "192.168.1.1:12345"
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}
}

func TestRateLimiterMiddleware_Exceeded(t *testing.T) {
	router := gin.New()
	router.Use(RateLimiterMiddleware())
	router.GET("/test-exceeded", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	for i := 0; i < RateLimit; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest("GET", "/test-exceeded", nil)
		req.RemoteAddr = "10.0.0.1:12345"
		router.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Fatalf("Request %d expected status 200, got %d", i+1, w.Code)
		}
	}

	// 61st request should be rate limited
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/test-exceeded", nil)
	req.RemoteAddr = "10.0.0.1:12345"
	router.ServeHTTP(w, req)

	if w.Code != http.StatusTooManyRequests {
		t.Errorf("Expected status 429, got %d", w.Code)
	}
}

func TestRateLimiterMiddleware_BypassHeader(t *testing.T) {
	router := gin.New()
	router.Use(RateLimiterMiddleware())
	router.GET("/test-bypass", func(c *gin.Context) {
		c.String(http.StatusOK, "OK")
	})

	for i := 0; i < RateLimit+10; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest("GET", "/test-bypass", nil)
		req.Header.Set("X-Load-Test-User-Id", "load-test-user")
		router.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Fatalf("Request %d with bypass header expected status 200, got %d", i+1, w.Code)
		}
	}
}

func TestSafeCounter_AtomicInc(t *testing.T) {
	var counter SafeCounter
	var wg sync.WaitGroup
	numRoutines := 50
	numIncrements := 100

	for i := 0; i < numRoutines; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < numIncrements; j++ {
				counter.Inc()
			}
		}()
	}

	wg.Wait()
	expected := numRoutines * numIncrements
	if int(counter.v) != expected {
		t.Errorf("Expected counter to be %d, got %d", expected, counter.v)
	}
}

func BenchmarkKeyFormatting_Sprintf(b *testing.B) {
	identifier := "user_123456789_test_identifier"
	minute := time.Now().Unix() / 60

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, minute)
	}
}

func BenchmarkKeyFormatting_Concat(b *testing.B) {
	identifier := "user_123456789_test_identifier"
	minute := time.Now().Unix() / 60

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(minute, 10)
	}
}

func BenchmarkSafeCounter_AtomicInc(b *testing.B) {
	var counter SafeCounter
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
