package middleware

import (
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gin-gonic/gin"
)

var (
	memoryStore   sync.Map
	cleanupTicker *time.Ticker
	cleanupDone   chan bool
	once          sync.Once
)

const (
	RateLimit   = 60 // Requests per minute
	Window      = 1 * time.Minute
	CleanupTick = 5 * time.Minute
)

// initMemory initializes the background cleanup for in-memory counting.
func initMemory() {
	once.Do(func() {
		cleanupTicker = time.NewTicker(CleanupTick)
		cleanupDone = make(chan bool)

		// Background cleanup for memory map: only remove buckets for minutes
		// that have already elapsed, so a client can't get a fresh quota by
		// having the entire map wiped mid-window.
		go func() {
			for {
				select {
				case <-cleanupTicker.C:
					currentMinute := time.Now().Unix() / 60
					memoryStore.Range(func(key, value interface{}) bool {
						k := key.(string)
						if idx := strings.LastIndex(k, ":"); idx != -1 {
							if minute, err := strconv.ParseInt(k[idx+1:], 10, 64); err == nil && minute < currentMinute {
								memoryStore.Delete(key)
							}
						}
						return true
					})
				case <-cleanupDone:
					return
				}
			}
		}()
	})
}

// RateLimiterMiddleware enforces rate limits in memory (Pure Supabase architecture fallback).
func RateLimiterMiddleware() gin.HandlerFunc {
	initMemory()

	return func(c *gin.Context) {
		// Load test/local dev bypass (only if GIN_MODE is not release)
		if bypassUID := c.GetHeader("X-Load-Test-User-Id"); bypassUID != "" && os.Getenv("GIN_MODE") != "release" {
			c.Next()
			return
		}

		userID := c.GetString("user_id")
		ip := c.ClientIP()

		// Identifier: Prefer UserID, fallback to IP
		identifier := userID
		if identifier == "" {
			identifier = ip
		}

		// Key: rate:{id}:{current_minute_unix} (direct string concatenation for zero fmt allocation)
		currentMinute := time.Now().Unix() / 60
		key := "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)

		// In-Memory Rate Limiter
		val, _ := memoryStore.LoadOrStore(key, &SafeCounter{})
		counter := val.(*SafeCounter)

		newVal := counter.Inc()
		if newVal > RateLimit {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error": "Rate limit exceeded (Local).",
			})
			return
		}

		c.Next()
	}
}

// SafeCounter is a thread-safe counter for memory fallback using lock-free atomic hardware instructions.
type SafeCounter struct {
	v int64
}

func (c *SafeCounter) Inc() int {
	return int(atomic.AddInt64(&c.v, 1))
}
