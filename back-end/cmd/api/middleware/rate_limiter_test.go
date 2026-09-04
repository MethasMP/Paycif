package middleware

import (
	"fmt"
	"strconv"
	"sync"
	"testing"
	"time"
)

// TestRateLimiter_KeyFormat verifies that direct string concatenation matches expected key format.
func TestRateLimiter_KeyFormat(t *testing.T) {
	identifier := "user_12345"
	currentMinute := time.Now().Unix() / 60

	expectedKey := fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	actualKey := "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)

	if actualKey != expectedKey {
		t.Fatalf("Key mismatch! Expected %q, got %q", expectedKey, actualKey)
	}
}

// TestSafeCounter_AtomicInc verifies thread safety and correctness of atomic SafeCounter.
func TestSafeCounter_AtomicInc(t *testing.T) {
	counter := &SafeCounter{}
	var wg sync.WaitGroup
	workers := 100
	incrementsPerWorker := 1000

	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < incrementsPerWorker; j++ {
				counter.Inc()
			}
		}()
	}

	wg.Wait()
	expectedTotal := workers * incrementsPerWorker
	if int(counter.v) != expectedTotal {
		t.Fatalf("Expected counter value %d, got %d", expectedTotal, counter.v)
	}
}

// BenchmarkRateLimiterKey_DirectConcat benchmarks direct string concatenation for key creation.
func BenchmarkRateLimiterKey_DirectConcat(b *testing.B) {
	identifier := "user_12345"
	currentMinute := int64(29283741)

	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = "rate:" + identifier + ":" + strconv.FormatInt(currentMinute, 10)
	}
}

// BenchmarkRateLimiterKey_Sprintf benchmarks fmt.Sprintf for key creation.
func BenchmarkRateLimiterKey_Sprintf(b *testing.B) {
	identifier := "user_12345"
	currentMinute := int64(29283741)

	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = fmt.Sprintf("rate:%s:%d", identifier, currentMinute)
	}
}

// BenchmarkSafeCounter_AtomicInc benchmarks lock-free atomic increment.
func BenchmarkSafeCounter_AtomicInc(b *testing.B) {
	counter := &SafeCounter{}

	b.ResetTimer()
	b.ReportAllocs()

	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			counter.Inc()
		}
	})
}
