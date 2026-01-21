package redis

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/redis/go-redis/v9"
)

// NewRedisClient initializes a new Redis client.
// Returns nil if REDIS_URL is not set or connection fails (allowing fallback).
func NewRedisClient() *redis.Client {
	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		log.Println("ℹ️ REDIS_URL not found. Using In-Memory Fallback options where available.")
		return nil
	}

	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Printf("⚠️ Invalid REDIS_URL: %v. Using Fallback.\n", err)
		return nil
	}

	client := redis.NewClient(opts)

	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if err := client.Ping(ctx).Err(); err != nil {
		log.Printf("⚠️ Redis unreachable: %v. Using Fallback.\n", err)
		return nil
	}

	log.Println("✅ Connected to Redis")
	return client
}
