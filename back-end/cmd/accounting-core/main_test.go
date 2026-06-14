package main

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestShardedLimitCache_Correctness(t *testing.T) {
	cache := NewShardedLimitCache(nil, 60*time.Second)
	userID := uuid.New()
	ctx := context.Background()

	// Initial check: transaction under daily and transaction limit
	allowed, remaining, msg, err := cache.CheckTransaction(ctx, userID, 100000) // 1,000 THB
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !allowed {
		t.Errorf("expected transaction to be allowed, message: %s", msg)
	}
	expectedRemaining := int64(MaxDailyLimit*100) - 100000
	if remaining != expectedRemaining {
		t.Errorf("expected remaining %d, got %d", expectedRemaining, remaining)
	}

	// Exceed single transaction limit (฿5,000 = 500000 satangs)
	allowed, _, msg, err = cache.CheckTransaction(ctx, userID, 500001)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if allowed {
		t.Error("expected transaction to be rejected (exceeds transaction limit)")
	}

	// Check daily limit (฿20,000 = 2,000,000 satangs)
	// Currently at 100,000. Add another 1,900,000 using 19 transactions of 100,000 satangs.
	for i := 0; i < 19; i++ {
		allowed, remaining, msg, err = cache.CheckTransaction(ctx, userID, 100000)
		if err != nil {
			t.Fatalf("unexpected error at iteration %d: %v", i, err)
		}
		if !allowed {
			t.Fatalf("expected transaction %d to be allowed, message: %s", i, msg)
		}
		expectedRemaining := int64(MaxDailyLimit*100) - (100000 + int64(i+1)*100000)
		if remaining != expectedRemaining {
			t.Errorf("expected remaining %d, got %d", expectedRemaining, remaining)
		}
	}

	// Exceed daily limit
	allowed, remaining, msg, err = cache.CheckTransaction(ctx, userID, 100)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if allowed {
		t.Error("expected transaction to be rejected (exceeds daily limit)")
	}
	if remaining != 0 {
		t.Errorf("expected remaining 0, got %d", remaining)
	}

	// Release limit
	cache.ReleaseLimit(userID, 50000)
	// Remaining should be 50,000
	_, _, _, remaining, _ = cache.GetLimits(ctx, userID)
	if remaining != 50000 {
		t.Errorf("expected remaining 50000, got %d", remaining)
	}
}

func TestShardedLimitCache_Concurrency(t *testing.T) {
	cache := NewShardedLimitCache(nil, 60*time.Second)
	userID := uuid.New()
	ctx := context.Background()

	// We want to run 100 concurrent workers trying to increment by 100 satangs each.
	// Since daily limit is 2,000,000, all 100 should succeed.
	var wg sync.WaitGroup
	workers := 100
	wg.Add(workers)

	for i := 0; i < workers; i++ {
		go func() {
			defer wg.Done()
			allowed, _, _, err := cache.CheckTransaction(ctx, userID, 100)
			if err != nil {
				t.Errorf("unexpected error: %v", err)
			}
			if !allowed {
				t.Error("expected transaction to be allowed")
			}
		}()
	}
	wg.Wait()

	currentDaily, _, _, remaining, err := cache.GetLimits(ctx, userID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	expectedDaily := int64(workers * 100)
	if currentDaily != expectedDaily {
		t.Errorf("expected daily total %d, got %d", expectedDaily, currentDaily)
	}
	expectedRemaining := int64(MaxDailyLimit*100) - expectedDaily
	if remaining != expectedRemaining {
		t.Errorf("expected remaining %d, got %d", expectedRemaining, remaining)
	}
}

func BenchmarkShardedLimitCache_CheckTransaction(b *testing.B) {
	cache := NewShardedLimitCache(nil, 60*time.Second)
	ctx := context.Background()

	// Warm up cache for multiple users so we do memory hits
	var users []uuid.UUID
	for i := 0; i < 1000; i++ {
		uid := uuid.New()
		users = append(users, uid)
		_, _, _, _ = cache.CheckTransaction(ctx, uid, 1)
	}

	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		i := 0
		for pb.Next() {
			// Check transaction on pre-cached users
			uid := users[i%len(users)]
			_, _, _, _ = cache.CheckTransaction(ctx, uid, 1)
			i++
		}
	})
}
