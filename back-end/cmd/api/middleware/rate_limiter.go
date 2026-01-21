package middleware

import (
	"context"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
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
// Uses sync.Once to ensure it starts only once if multiple middlewares are created (rare but safe).
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

// RateLimiterMiddleware enforces rate limits.
// Accepts an injected Redis client. If nil, strict in-memory fallback is used.
func RateLimiterMiddleware(rdb *redis.Client) gin.HandlerFunc {
	useRedis := (rdb != nil)

	if !useRedis {
		initMemory()
	}

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

		if useRedis {
			ctx := context.Background()
			// INCR and EXPIRE
			count, err := rdb.Incr(ctx, key).Result()
			if err != nil {
				// Redis fail open -> allow request
				c.Next()
				return
			}
			if count == 1 {
				rdb.Expire(ctx, key, Window)
			}

			if count > RateLimit {
				c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
					"error": "Rate limit exceeded. Try again later.",
				})
				return
			}
		} else {
			// In-Memory Fallback
			val, _ := memoryStore.LoadOrStore(key, &SafeCounter{})
			counter := val.(*SafeCounter)
			
			newVal := counter.Inc()
			if newVal > RateLimit {
				c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
					"error": "Rate limit exceeded (Local).",
				})
				return
			}
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
