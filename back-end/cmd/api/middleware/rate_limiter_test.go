package middleware_test

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
	"time"

	"paysif/cmd/api/middleware"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

func TestRateLimiterMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)

	t.Run("Allows requests within limit", func(t *testing.T) {
		r := gin.New()
		r.Use(func(c *gin.Context) {
			c.Set("user_id", "user-test-123")
			c.Next()
		})
		r.Use(middleware.RateLimiterMiddleware())
		r.GET("/test", func(c *gin.Context) {
			c.String(http.StatusOK, "ok")
		})

		req := httptest.NewRequest(http.MethodGet, "/test", nil)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		assert.Equal(t, http.StatusOK, w.Code)
		assert.Equal(t, "ok", w.Body.String())
	})

	t.Run("Aborts with HTTP 429 when rate limit exceeded", func(t *testing.T) {
		r := gin.New()
		r.Use(func(c *gin.Context) {
			c.Set("user_id", "user-limit-exceeded-429")
			c.Next()
		})
		r.Use(middleware.RateLimiterMiddleware())
		r.GET("/test-429", func(c *gin.Context) {
			c.String(http.StatusOK, "ok")
		})

		for i := 0; i < middleware.RateLimit; i++ {
			req := httptest.NewRequest(http.MethodGet, "/test-429", nil)
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)
			assert.Equal(t, http.StatusOK, w.Code)
		}

		// Next request should be rate limited
		req := httptest.NewRequest(http.MethodGet, "/test-429", nil)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		assert.Equal(t, http.StatusTooManyRequests, w.Code)
	})
}

func BenchmarkRateLimitKeyFormat_Concat(b *testing.B) {
	identifier := "user-12345-abcde"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

func BenchmarkRateLimitKeyFormat_Sprintf(b *testing.B) {
	identifier := "user-12345-abcde"
	currentMinute := time.Now().Unix() / 60
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}
