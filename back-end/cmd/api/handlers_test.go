package main

import (
	"fmt"
	"hash/fnv"
	"strconv"
	"testing"

	"github.com/stretchr/testify/assert"
)

func generateETagLegacy(maxDaily, currentTotal, remaining float64, userIDStr string) string {
	fingerprint := fmt.Sprintf("%v-%v-%v-%v",
		maxDaily,
		currentTotal,
		remaining,
		userIDStr)

	hasher := fnv.New64a()
	hasher.Write([]byte(fingerprint))
	return fmt.Sprintf("\"%x\"", hasher.Sum64())
}

func generateETagOptimized(maxDaily, currentTotal, remaining float64, userIDStr string) string {
	hasher := fnv.New64a()
	var buf [32]byte

	hasher.Write(strconv.AppendFloat(buf[:0], maxDaily, 'f', -1, 64))
	hasher.Write([]byte{'-'})
	hasher.Write(strconv.AppendFloat(buf[:0], currentTotal, 'f', -1, 64))
	hasher.Write([]byte{'-'})
	hasher.Write(strconv.AppendFloat(buf[:0], remaining, 'f', -1, 64))
	hasher.Write([]byte{'-'})
	hasher.Write([]byte(userIDStr))

	return "\"" + strconv.FormatUint(hasher.Sum64(), 16) + "\""
}

func TestETagEquivalence(t *testing.T) {
	testCases := []struct {
		name         string
		maxDaily     float64
		currentTotal float64
		remaining    float64
		userID       string
	}{
		{
			name:         "Standard limits",
			maxDaily:     100000.0,
			currentTotal: 25000.0,
			remaining:    75000.0,
			userID:       "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
		},
		{
			name:         "Zero values",
			maxDaily:     0.0,
			currentTotal: 0.0,
			remaining:    0.0,
			userID:       "00000000-0000-0000-0000-000000000000",
		},
		{
			name:         "Decimal limits",
			maxDaily:     50000.50,
			currentTotal: 1234.75,
			remaining:    48765.75,
			userID:       "12345678-abcd-ef01-2345-6789abcdef01",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			legacy := generateETagLegacy(tc.maxDaily, tc.currentTotal, tc.remaining, tc.userID)
			optimized := generateETagOptimized(tc.maxDaily, tc.currentTotal, tc.remaining, tc.userID)
			assert.Equal(t, legacy, optimized, "Optimized ETag generation must produce identical results to legacy fmt.Sprintf")
		})
	}
}

func BenchmarkETagFormatting(b *testing.B) {
	maxDaily := 100000.0
	currentTotal := 25000.0
	remaining := 75000.0
	userIDStr := "a1b2c3d4-e5f6-7890-abcd-ef1234567890"

	b.Run("Legacy_fmt_Sprintf", func(b *testing.B) {
		b.ReportAllocs()
		for i := 0; i < b.N; i++ {
			_ = generateETagLegacy(maxDaily, currentTotal, remaining, userIDStr)
		}
	})

	b.Run("Optimized_Direct_Write", func(b *testing.B) {
		b.ReportAllocs()
		for i := 0; i < b.N; i++ {
			_ = generateETagOptimized(maxDaily, currentTotal, remaining, userIDStr)
		}
	})
}
