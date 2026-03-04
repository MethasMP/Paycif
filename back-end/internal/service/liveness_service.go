package service

import (
	"math"
	"math/cmplx"
)

// LivenessService handles advanced anti-spoofing logic.
type LivenessService struct{}

func NewLivenessService() *LivenessService {
	return &LivenessService{}
}

// VerifyPulse checks if the provided green channel intensity series contains a human heartbeat.
// samples: Mean green values per frame (e.g., 30fps * 4s = 120 samples)
// fps: Frames per second of the video
func (s *LivenessService) VerifyPulse(samples []float64, fps float64) (bool, float64) {
	n := len(samples)
	if n < 60 {
		return false, 0
	}

	// 1. Detrending
	mean := 0.0
	for _, v := range samples {
		mean += v
	}
	mean /= float64(n)
	
	detrended := make([]float64, n)
	for i, v := range samples {
		detrended[i] = v - mean
	}

	// 2. DFT with Zero-Padding (Tesla optimization for high resolution)
	paddedN := 512
	if n > paddedN {
		paddedN = n
	}

	maxMag := 0.0
	heartRateBPM := 0.0
	totalMag := 0.0
	validBins := 0

	minFreq := 0.75 // 45 BPM
	maxFreq := 3.0  // 180 BPM

	for k := 1; k < paddedN/2; k++ {
		var sum complex128
		freq := float64(k) * fps / float64(paddedN)
		
		// Optimization: Focus on human HR range
		if freq < 0.5 || freq > 4.0 {
			continue
		}

		for t := 0; t < n; t++ {
			angle := 2.0 * math.Pi * float64(k) * float64(t) / float64(paddedN)
			sum += complex(detrended[t], 0) * cmplx.Exp(complex(0, -angle))
		}
		
		mag := cmplx.Abs(sum)
		totalMag += mag
		validBins++
		
		if freq >= minFreq && freq <= maxFreq {
			if mag > maxMag {
				maxMag = mag
				heartRateBPM = freq * 60
			}
		}
	}

	// 3. SNR check
	// Calculate average noise floor in the valid range
	avgMag := totalMag / float64(validBins)
	snr := 0.0
	if avgMag > 0 {
		snr = maxMag / avgMag
	}

	// Thresholds:
	// A human heartbeat has high SNR (>3) and falls in physiological range.
	// maxMag check ensures we aren't just looking at tiny noise.
	isLive := snr > 3.0 && maxMag > 1.0 && heartRateBPM >= 45 && heartRateBPM <= 160

	return isLive, heartRateBPM
}
