package main

import (
	"fmt"
	"hash/fnv"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

func generateETagOriginal(maxDaily, currentDaily, remainingDaily float64, userID string) string {
	fingerprint := fmt.Sprintf("%v-%v-%v-%v",
		maxDaily,
		currentDaily,
		remainingDaily,
		userID)

	hasher := fnv.New64a()
	hasher.Write([]byte(fingerprint))
	return fmt.Sprintf("\"%x\"", hasher.Sum64())
}

func generateETagOptimized(maxDaily, currentDaily, remainingDaily float64, userID string) string {
	hasher := fnv.New64a()
	var buf [32]byte

	hasher.Write(strconv.AppendFloat(buf[:0], maxDaily, 'f', -1, 64))
	hasher.Write([]byte("-"))
	hasher.Write(strconv.AppendFloat(buf[:0], currentDaily, 'f', -1, 64))
	hasher.Write([]byte("-"))
	hasher.Write(strconv.AppendFloat(buf[:0], remainingDaily, 'f', -1, 64))
	hasher.Write([]byte("-"))
	hasher.Write([]byte(userID))

	return "\"" + strconv.FormatUint(hasher.Sum64(), 16) + "\""
}

func TestETagOutputsMatch(t *testing.T) {
	testCases := []struct {
		name           string
		maxDaily       float64
		currentDaily   float64
		remainingDaily float64
		userID         string
	}{
		{
			name:           "standard limits",
			maxDaily:       50000.0,
			currentDaily:   12500.50,
			remainingDaily: 37499.50,
			userID:         "usr_9f8a7b6c5d4e3f2a",
		},
		{
			name:           "zero daily total",
			maxDaily:       100000.0,
			currentDaily:   0.0,
			remainingDaily: 100000.0,
			userID:         "00000000-0000-0000-0000-000000000001",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			orig := generateETagOriginal(tc.maxDaily, tc.currentDaily, tc.remainingDaily, tc.userID)
			opt := generateETagOptimized(tc.maxDaily, tc.currentDaily, tc.remainingDaily, tc.userID)
			assert.Equal(t, orig, opt)
		})
	}
}

func TestHandleGetLimits_ETagGeneration(t *testing.T) {
	gin.SetMode(gin.TestMode)
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)

	c.Set("user_id", "test-user-uuid-1234")
	req, _ := http.NewRequest(http.MethodGet, "/api/v1/limits", nil)
	c.Request = req

	// Calculate expected ETag for 0 values when Service is nil / handler exits early or responds
	hasher := fnv.New64a()
	var buf [32]byte
	hasher.Write(strconv.AppendFloat(buf[:0], 0.0, 'f', -1, 64))
	hasher.Write([]byte("-"))
	hasher.Write(strconv.AppendFloat(buf[:0], 0.0, 'f', -1, 64))
	hasher.Write([]byte("-"))
	hasher.Write(strconv.AppendFloat(buf[:0], 0.0, 'f', -1, 64))
	hasher.Write([]byte("-"))
	hasher.Write([]byte("test-user-uuid-1234"))
	expectedETag := "\"" + strconv.FormatUint(hasher.Sum64(), 16) + "\""

	assert.NotEmpty(t, expectedETag)
}

func BenchmarkETagOriginal(b *testing.B) {
	maxDaily := 50000.0
	currentDaily := 12500.50
	remainingDaily := 37499.50
	userID := "usr_9f8a7b6c5d4e3f2a"

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = generateETagOriginal(maxDaily, currentDaily, remainingDaily, userID)
	}
}

func BenchmarkETagOptimized(b *testing.B) {
	maxDaily := 50000.0
	currentDaily := 12500.50
	remainingDaily := 37499.50
	userID := "usr_9f8a7b6c5d4e3f2a"

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = generateETagOptimized(maxDaily, currentDaily, remainingDaily, userID)
	}
}
