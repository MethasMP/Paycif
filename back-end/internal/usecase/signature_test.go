package usecase_test

import (
	"fmt"
	"strconv"
	"testing"
	"time"

	"paysif/internal/usecase"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestVerifyTimestampBucket(t *testing.T) {
	svc := usecase.NewSignatureService(nil, "")

	currentBucket := time.Now().Unix() / 60

	t.Run("Valid Current Bucket", func(t *testing.T) {
		bucketStr := strconv.FormatInt(currentBucket, 10)
		err := svc.VerifyTimestampBucket(bucketStr)
		assert.NoError(t, err)
	})

	t.Run("Valid Drift - 1 Min Old", func(t *testing.T) {
		bucketStr := strconv.FormatInt(currentBucket-1, 10)
		err := svc.VerifyTimestampBucket(bucketStr)
		assert.NoError(t, err)
	})

	t.Run("Valid Drift - 2 Mins Future", func(t *testing.T) {
		bucketStr := strconv.FormatInt(currentBucket+2, 10)
		err := svc.VerifyTimestampBucket(bucketStr)
		assert.NoError(t, err)
	})

	t.Run("Expired Drift - 3 Mins Old", func(t *testing.T) {
		bucketStr := strconv.FormatInt(currentBucket-3, 10)
		err := svc.VerifyTimestampBucket(bucketStr)
		require.Error(t, err)
		assert.Contains(t, err.Error(), "expired or invalid replay window")
	})

	t.Run("Missing Header", func(t *testing.T) {
		err := svc.VerifyTimestampBucket("")
		require.Error(t, err)
		assert.Contains(t, err.Error(), "missing timestamp bucket header")
	})

	t.Run("Invalid Format", func(t *testing.T) {
		err := svc.VerifyTimestampBucket("invalid_number")
		require.Error(t, err)
		assert.Contains(t, err.Error(), "invalid timestamp bucket format")
	})
}

func BenchmarkVerifyTimestampBucket(b *testing.B) {
	svc := usecase.NewSignatureService(nil, "")
	currentBucket := time.Now().Unix() / 60
	bucketStr := strconv.FormatInt(currentBucket, 10)

	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = svc.VerifyTimestampBucket(bucketStr)
	}
}

// BenchmarkVerifyTimestampBucket_FmtSscanf tests the legacy Sscanf implementation for benchmark comparison.
func BenchmarkVerifyTimestampBucket_FmtSscanf(b *testing.B) {
	currentBucket := time.Now().Unix() / 60
	bucketStr := strconv.FormatInt(currentBucket, 10)

	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		var clientBucket int64
		_, _ = fmt.Sscanf(bucketStr, "%d", &clientBucket)
	}
}
