package service

import (
	"context"
	"fmt"
	"time"

	"github.com/sony/gobreaker"
)

// SanctionsService checks users against global sanctions lists (OFAC, UN, EU).
type SanctionsService struct {
	cb *gobreaker.CircuitBreaker
}

// NewSanctionsService creates a new sanctions service with a circuit breaker.
func NewSanctionsService() *SanctionsService {
	settings := gobreaker.Settings{
		Name:        "SanctionsListAPI",
		MaxRequests: 5,
		Interval:    10 * time.Second,
		Timeout:     30 * time.Second,
		ReadyToTrip: func(counts gobreaker.Counts) bool {
			failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
			return counts.Requests >= 3 && failureRatio >= 0.6
		},
	}

	return &SanctionsService{
		cb: gobreaker.NewCircuitBreaker(settings),
	}
}

// IsWhitelisted checks if the identity is clear of sanctions.
func (s *SanctionsService) IsWhitelisted(ctx context.Context, fullName string, nationality string) (bool, error) {
	result, err := s.cb.Execute(func() (interface{}, error) {
		// Simulation: Call a global AML/Sanctions API
		// resp, err := http.Get(fmt.Sprintf("https://api.sanctions-standard.com/check?name=%s", fullName))
		
		// For now, we simulate a fast response for "Standard" logic
		// But if this was down, the circuit breaker would open and save the system's performance.
		time.Sleep(50 * time.Millisecond) 
		
		return true, nil
	})

	if err != nil {
		return false, fmt.Errorf("sanctions check unavailable (Circuit Breaker): %w", err)
	}

	return result.(bool), nil
}
