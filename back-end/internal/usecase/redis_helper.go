package usecase

import (
	"context"
	"log"
	"os"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"
)

var (
	redisClient *redis.Client
	redisOnce   sync.Once
	DisableRedisCacheForTesting = false
)

// GetRedisClient retrieves or initializes the shared Redis client connection.
func GetRedisClient() *redis.Client {
	if DisableRedisCacheForTesting {
		return nil
	}
	redisOnce.Do(func() {
		redisURL := os.Getenv("REDIS_URL")
		if redisURL == "" {
			redisURL = "redis://127.0.0.1:6379/0"
		}
		opt, err := redis.ParseURL(redisURL)
		if err != nil {
			log.Printf("⚠️ Redis parsing failed: %v. Running without Redis L2 caching.", err)
			return
		}
		client := redis.NewClient(opt)
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()

		if err := client.Ping(ctx).Err(); err != nil {
			log.Printf("⚠️ Redis connection ping failed: %v. Running without Redis L2 caching.", err)
			client.Close()
			return
		}

		redisClient = client
		log.Println("✅ Shared Redis client initialized successfully for geo/VPN caching.")
	})
	return redisClient
}

// CacheGet reads a value from Redis if available.
func CacheGet(ctx context.Context, key string) (string, bool) {
	rdb := GetRedisClient()
	if rdb == nil {
		return "", false
	}
	val, err := rdb.Get(ctx, key).Result()
	if err != nil {
		return "", false
	}
	return val, true
}

// CacheSet writes a value to Redis if available.
func CacheSet(ctx context.Context, key string, value string, ttl time.Duration) {
	rdb := GetRedisClient()
	if rdb == nil {
		return
	}
	_ = rdb.Set(ctx, key, value, ttl).Err()
}
