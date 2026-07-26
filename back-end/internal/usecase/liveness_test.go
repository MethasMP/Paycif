package usecase

import (
	"math"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestLivenessService_VerifyPulse(t *testing.T) {
	svc := NewLivenessService()
	fps := 30.0
	duration := 4.0 // seconds
	n := int(fps * duration)

	t.Run("Valid Heartbeat (72 BPM)", func(t *testing.T) {
		bpm := 72.0
		freq := bpm / 60.0

		samples := make([]float64, n)
		for i := 0; i < n; i++ {
			// Simulate pulsatile signal with some noise
			samples[i] = math.Sin(2.0*math.Pi*freq*float64(i)/fps) + 0.1
		}

		isLive, detectedBPM := svc.VerifyPulse(samples, fps)

		assert.True(t, isLive)
		assert.InDelta(t, bpm, detectedBPM, 2.0)
	})

	t.Run("Static/Background Signal (No Life)", func(t *testing.T) {
		samples := make([]float64, n)
		for i := 0; i < n; i++ {
			samples[i] = 128.0 // Constant intensity
		}

		isLive, _ := svc.VerifyPulse(samples, fps)
		assert.False(t, isLive)
	})

	t.Run("Random Noise (No Life)", func(t *testing.T) {
		samples := make([]float64, n)
		for i := 0; i < n; i++ {
			samples[i] = math.Log(float64(i + 1)) // Non-rhythmic drift
		}

		isLive, _ := svc.VerifyPulse(samples, fps)
		assert.False(t, isLive)
	})
}

func BenchmarkLivenessService_VerifyPulse(b *testing.B) {
	svc := NewLivenessService()
	fps := 30.0
	duration := 4.0 // seconds
	n := int(fps * duration)
	bpm := 72.0
	freq := bpm / 60.0

	samples := make([]float64, n)
	for i := 0; i < n; i++ {
		samples[i] = math.Sin(2.0*math.Pi*freq*float64(i)/fps) + 0.1
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = svc.VerifyPulse(samples, fps)
	}
}
