package usecase

import (
	"math"
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
	// Calculate mean sample value. To avoid heap allocation of an intermediate
	// 'detrended' slice, detrending is performed on-the-fly inside the DFT loop.
	mean := 0.0
	for _, v := range samples {
		mean += v
	}
	mean /= float64(n)

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

	// Optimization: Pre-calculate scaling factor and DFT loop constants.
	// Replacing cmplx.Exp/cmplx.Abs with direct math.Sincos/math.Hypot avoids
	// complex struct allocations/conversions and speeds up computation.
	angleFactor := -2.0 * math.Pi / float64(paddedN)

	for k := 1; k < paddedN/2; k++ {
		freq := float64(k) * fps / float64(paddedN)

		// Optimization: Focus on human HR range
		if freq < 0.5 || freq > 4.0 {
			continue
		}

		kAngle := float64(k) * angleFactor
		var realSum, imagSum float64

		for t := 0; t < n; t++ {
			detrendedVal := samples[t] - mean
			angle := kAngle * float64(t)
			sinVal, cosVal := math.Sincos(angle)
			realSum += detrendedVal * cosVal
			imagSum += detrendedVal * sinVal
		}

		mag := math.Hypot(realSum, imagSum)
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
