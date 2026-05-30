package middleware

import (
	"fmt"
	"net/http"
	"sync"
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
	RateLimit   = 60             // Requests per minute
	Window      = 1 * time.Minute
	CleanupTick = 5 * time.Minute
)

// initMemory initializes the background cleanup for in-memory counting.
func initMemory() {
	once.Do(func() {
		cleanupTicker = time.NewTicker(CleanupTick)
		cleanupDone = make(chan bool)

		// Background cleanup for memory map
		go func() {
			for {
				select {
				case <-cleanupTicker.C:
					memoryStore.Range(func(key, value interface{}) bool {
						memoryStore.Delete(key)
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
		userID := c.GetString("user_id")
		ip := c.ClientIP()
		
		// Identifier: Prefer UserID, fallback to IP
		identifier := userID
		if identifier == "" {
			identifier = ip
		}

		// Key: rate:{id}:{current_minute_unix}
		currentMinute := time.Now().Unix() / 60
		key := fmt.Sprintf("rate:%s:%d", identifier, currentMinute)

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

// SafeCounter is a thread-safe counter for memory fallback
type SafeCounter struct {
	v   int
	mux sync.Mutex
}

func (c *SafeCounter) Inc() int {
	c.mux.Lock()
	defer c.mux.Unlock()
	c.v++
	return c.v
}

